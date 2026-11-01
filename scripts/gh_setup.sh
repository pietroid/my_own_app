#!/usr/bin/env bash
# Sets the secrets and variables .github/workflows/deploy.yml needs on a
# GitHub repository.
#
# The SSH side comes from the Pi itself, over your own SSH access to it
# (PI_SSH_HOST, `focus` from ~/.ssh/config by default): the user the deploy
# logs in as, and the private half of a deploy key kept on the Pi
# (~/.ssh/github_deploy, created and authorized there on first use). The key
# goes straight from the Pi to GitHub and is never written on this machine.
#
# The Cloudflare side is the same for every app, so it lives once in a local
# file outside any repository; the first run writes a template there:
#
#   ~/.config/pi-deploy/deploy.env   (or PI_DEPLOY_CONFIG=<file>)
#
#   scripts/gh_setup.sh                    # this repository
#   scripts/gh_setup.sh pietroid/other     # another one
set -euo pipefail

config=${PI_DEPLOY_CONFIG:-$HOME/.config/pi-deploy/deploy.env}
repo=${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}

if [[ ! -f $config ]]; then
  mkdir -p "$(dirname "$config")"
  umask 077
  cat > "$config" << 'EOF'
# Shared by every app deployed to the Pi (scripts/gh_setup.sh).

# How you reach the Pi over SSH from this machine (a ~/.ssh/config alias).
PI_SSH_HOST=focus

# The tunnel hostname the deploy SSHes in through.
CLOUDFLARE_SSH_HOSTNAME=deploy.<your-domain>

# Cloudflare Zero Trust -> Access -> Service Auth -> Service Tokens.
TUNNEL_SERVICE_TOKEN_ID=
TUNNEL_SERVICE_TOKEN_SECRET=
EOF
  echo "Wrote a template to $config: fill it in and run this again."
  exit 1
fi

# shellcheck source=/dev/null
source "$config"
PI_SSH_HOST=${PI_SSH_HOST:-focus}
missing=()
for name in PI_SSH_HOST CLOUDFLARE_SSH_HOSTNAME TUNNEL_SERVICE_TOKEN_ID TUNNEL_SERVICE_TOKEN_SECRET; do
  [[ -n ${!name:-} ]] || missing+=("$name")
done
if (( ${#missing[@]} )); then
  printf 'Missing in %s: %s\n' "$config" "${missing[*]}" >&2
  exit 1
fi

echo "Reading the deploy key from $PI_SSH_HOST"
# Prints the user on the first line, then the private key.
from_pi=$(ssh "$PI_SSH_HOST" '
  set -e
  key=~/.ssh/github_deploy
  if [ ! -f "$key" ]; then
    ssh-keygen -q -t ed25519 -N "" -C "github-deploy@$(hostname)" -f "$key"
  fi
  touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
  grep -qxF "$(cat "$key.pub")" ~/.ssh/authorized_keys || cat "$key.pub" >> ~/.ssh/authorized_keys
  whoami
  cat "$key"
')
pi_user=$(head -n1 <<< "$from_pi")
private_key=$(tail -n +2 <<< "$from_pi")
if [[ -z $pi_user || $private_key != "-----BEGIN OPENSSH PRIVATE KEY-----"* ]]; then
  echo "Could not read the deploy key from $PI_SSH_HOST" >&2
  exit 1
fi

echo "Setting deploy secrets and variables on $repo"
gh variable set PI_USER -R "$repo" --body "$pi_user"
gh variable set CLOUDFLARE_SSH_HOSTNAME -R "$repo" --body "$CLOUDFLARE_SSH_HOSTNAME"
# Secrets through stdin, so they never show up in the process list.
printf '%s\n' "$private_key" | gh secret set PI_SSH_PRIVATE_KEY -R "$repo"
printf '%s' "$TUNNEL_SERVICE_TOKEN_ID" | gh secret set TUNNEL_SERVICE_TOKEN_ID -R "$repo"
printf '%s' "$TUNNEL_SERVICE_TOKEN_SECRET" | gh secret set TUNNEL_SERVICE_TOKEN_SECRET -R "$repo"
echo "Done (PI_USER=$pi_user)."
