#!/usr/bin/env bash
# Prepares the Raspberry Pi for this app, deployed by
# .github/workflows/deploy.yml: creates /opt/<app>, installs its .env (the
# server's production settings plus the two ports), and routes the public
# hostname to it through the Cloudflare tunnel (scripts/cloudflare_add_domain.sh,
# which must sit next to this script).
#
# Run it on the Pi, as the user the deploy logs in as (PI_USER). The setup
# CLI does this for you:
#
#   scp scripts/pi_setup.sh scripts/cloudflare_add_domain.sh server.env focus:
#   ssh -t focus ./pi_setup.sh my-own-app 8100 3100 <your-domain> server.env
#
# The env file is moved into /opt/<app>/.env (an existing one is kept as
# .env.bak). Without it, an existing .env stays and only its ports change.
set -euo pipefail

usage="usage: $0 <app> <web port> <backend port> [hostname] [env file]"
app=${1:?$usage}
web_port=${2:?$usage}
backend_port=${3:?$usage}
host=${4:-}
new_env=${5:-}
dir="/opt/$app"
env_file="$dir/.env"

[[ $app =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "app must be lowercase letters, digits and '-'" >&2; exit 1; }
[[ $web_port =~ ^[0-9]+$ && $backend_port =~ ^[0-9]+$ ]] || { echo "ports must be numbers" >&2; exit 1; }

command -v docker > /dev/null || { echo "docker is not installed" >&2; exit 1; }
if ! docker info > /dev/null 2>&1; then
  echo "$USER cannot use docker; run: sudo usermod -aG docker $USER (then log in again)" >&2
  exit 1
fi

# Another container (or anything else) on a port would make compose fail
# only at the first deploy, so check now. Our own containers may hold them.
for pair in "web:$web_port" "backend:$backend_port"; do
  port=${pair#*:}
  if ss -ltnH "sport = :$port" | grep -q . \
      && ! docker ps --format '{{.Names}} {{.Ports}}' | grep -q "^$app-${pair%%:*} .*:$port->"; then
    echo "port $port is already taken:" >&2
    ss -ltnpH "sport = :$port" >&2 || true
    exit 1
  fi
done

if [[ ! -d $dir ]]; then
  sudo mkdir -p "$dir"
  sudo chown "$USER" "$dir"
fi

umask 077
if [[ -n $new_env ]]; then
  [[ -f $new_env ]] || { echo "no such env file: $new_env" >&2; exit 1; }
  [[ -f $env_file ]] && cp "$env_file" "$env_file.bak"
  mv "$new_env" "$env_file"
  echo "Installed $env_file"
elif [[ ! -f $env_file ]]; then
  echo "No $env_file yet: pass the server's env file as the fifth argument" >&2
  exit 1
fi

# The ports compose publishes, kept at the end of the file.
sed -i -e '/^WEB_PORT=/d' -e '/^BACKEND_PORT=/d' "$env_file"
printf 'WEB_PORT=%s\nBACKEND_PORT=%s\n' "$web_port" "$backend_port" >> "$env_file"
chmod 600 "$env_file"

# A running container only picks up a new .env when recreated.
if [[ -f $dir/docker-compose.yml ]]; then
  (cd "$dir" && docker compose up -d)
fi

if [[ -n $host ]]; then
  "$(dirname "$0")/cloudflare_add_domain.sh" "$host" "$web_port"
fi

echo
echo "App:      $app"
echo "Folder:   $dir"
echo "Ports:    web $web_port, backend $backend_port (127.0.0.1)"
[[ -n $host ]] && echo "URL:      https://$host"
