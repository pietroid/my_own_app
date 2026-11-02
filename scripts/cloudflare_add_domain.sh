#!/usr/bin/env bash
# Routes a public hostname (e.g. xyz.pietroteruya.dev or app.my-own.app) to a
# port on the Pi through its Cloudflare Tunnel, and creates the DNS record.
# Safe to run again.
#
# Run it on the Pi, where cloudflared runs:
#
#   ./cloudflare_add_domain.sh xyz.pietroteruya.dev 8091
#   ./cloudflare_add_domain.sh app.my-own.app 8091
#
# It works with either way of managing the tunnel:
#
# - a config file (/etc/cloudflared/config.yml, the usual case after
#   `cloudflared tunnel create`): adds an ingress rule above the catch-all,
#   creates the DNS record and restarts cloudflared. With CF_API_TOKEN set
#   the record goes through the API, which finds the zone the hostname is in;
#   without it, through `cloudflared tunnel route dns`, which uses the
#   cert.pem from `cloudflared tunnel login`. That cert belongs to ONE zone,
#   and for a hostname in another zone cloudflared quietly creates
#   <host>.<cert zone> instead (my-own.app -> my-own.app.pietroteruya.dev);
#   the script checks for that and stops with what to do;
# - the dashboard (cloudflared runs with `--token`): edits the tunnel's
#   configuration and DNS through the API. Needs jq and CF_API_TOKEN, an API
#   token with Account > Cloudflare Tunnel > Edit and Zone > DNS > Edit.
set -euo pipefail

usage="usage: $0 <hostname> <local port>"
host=${1:?$usage}
port=${2:?$usage}
service="http://localhost:$port"

api="https://api.cloudflare.com/client/v4"

cf() {
  local out
  out=$(curl -sS -H "Authorization: Bearer $CF_API_TOKEN" -H 'Content-Type: application/json' "$@")
  if [[ $(jq -r .success <<< "$out") != true ]]; then
    echo "Cloudflare API: $(jq -c .errors <<< "$out")" >&2
    exit 1
  fi
  printf '%s' "$out"
}

# A proxied CNAME <host> -> <tunnel>.cfargotunnel.com, through the API.
dns_record_via_api() {
  local tunnel=$1 zone zone_id record record_id
  command -v jq > /dev/null || { echo "jq is needed: sudo apt install jq" >&2; exit 1; }
  # Find the zone the token can manage that is a suffix of the host. This
  # handles both apex domains (my-own.app) and subdomains (app.my-own.app),
  # and avoids guessing how many labels the registered zone has.
  zone=$(cf "$api/zones?per_page=50" | jq -r --arg h "$host" '
    .result
    | map(select(. as $zone | $h == $zone.name or ($h | endswith("." + $zone.name))))
    | sort_by(-(.name | length))
    | .[0].name // empty
  ')
  zone_id=$(cf "$api/zones?name=$zone" | jq -r '.result[0].id // empty')
  [[ -n $zone_id ]] || { echo "No Cloudflare zone found for $host with this API token" >&2; exit 1; }
  record=$(jq -n --arg h "$host" --arg t "$tunnel.cfargotunnel.com" \
    '{type: "CNAME", name: $h, content: $t, proxied: true}')
  record_id=$(cf "$api/zones/$zone_id/dns_records?name=$host" | jq -r '.result[0].id // empty')
  if [[ -n $record_id ]]; then
    cf -X PUT "$api/zones/$zone_id/dns_records/$record_id" --data "$record" > /dev/null
    echo "Updated DNS record $host"
  else
    cf -X POST "$api/zones/$zone_id/dns_records" --data "$record" > /dev/null
    echo "Created DNS record $host"
  fi
}

# The same record through the cert.pem, then a check of the name it got.
dns_record_via_cert() {
  local tunnel=$1 out fqdn
  # As the user, not root: the cert.pem lives in ~/.cloudflared.
  out=$(cloudflared tunnel route dns "$tunnel" "$host" 2>&1) || { echo "$out" >&2; exit 1; }
  echo "$out"
  # cloudflared names the record it touched: "Added CNAME <fqdn> which will
  # route to this tunnel" or "<fqdn> is already configured to route to ...".
  fqdn=$(grep -oE '(CNAME [^ ]+|[^ ]+ is already configured)' <<< "$out" | head -1 \
    | sed -E 's/^CNAME //; s/ is already configured$//; s/\.$//' || true)
  if [[ -n $fqdn && $fqdn != "$host" ]]; then
    cat >&2 <<MSG

The DNS record went to the wrong zone: cloudflared made $fqdn, not $host,
because its cert.pem belongs to another zone. Either run this again with
CF_API_TOKEN set (Zone > DNS > Edit), or in the Cloudflare dashboard, in the
zone of $host, add a proxied CNAME $host -> $tunnel.cfargotunnel.com.
Then delete the stray record $fqdn.
MSG
    exit 1
  fi
}

exec_start=$(systemctl cat cloudflared 2> /dev/null | grep -m1 '^ExecStart=' || true)
if [[ -z $exec_start ]]; then
  echo "No cloudflared systemd service found on this machine" >&2
  exit 1
fi

route_with_config_file() {
  local config tunnel tmp
  config=$(grep -oP -- '--config[= ]\K\S+' <<< "$exec_start" || true)
  for candidate in "$config" /etc/cloudflared/config.yml "$HOME/.cloudflared/config.yml"; do
    [[ -n $candidate && -f $candidate ]] && { config=$candidate; break; }
  done
  [[ -f $config ]] || { echo "No cloudflared config file found" >&2; exit 1; }
  tunnel=$(awk '/^tunnel:/ { print $2; exit }' "$config")
  echo "Tunnel $tunnel, config $config"

  if grep -Eq "hostname:[[:space:]]*$host[[:space:]]*$" "$config"; then
    echo "$host is already in the ingress rules; leaving them as they are"
  else
    tmp=$(mktemp)
    # The new rule goes right above the catch-all, indented like it.
    if ! awk -v host="$host" -v svc="$service" '
      !done && /^[[:space:]]*-[[:space:]]*service:[[:space:]]*http_status:/ {
        match($0, /^[[:space:]]*/)
        indent = substr($0, 1, RLENGTH)
        print indent "- hostname: " host
        print indent "  service: " svc
        done = 1
      }
      { print }
      END { if (!done) exit 3 }
    ' "$config" > "$tmp"; then
      rm -f "$tmp"
      echo "No catch-all rule (- service: http_status:404) in $config" >&2
      exit 1
    fi
    sudo cp "$config" "$config.bak"
    sudo cp "$tmp" "$config"
    rm -f "$tmp"
    echo "Added $host -> $service (previous config in $config.bak)"
  fi

  cloudflared --config "$config" tunnel ingress validate
  cloudflared --config "$config" tunnel ingress rule "https://$host"
  if [[ -n ${CF_API_TOKEN:-} ]]; then
    # The config file may name the tunnel; the record needs its id.
    [[ $tunnel =~ ^[0-9a-f-]{36}$ ]] || tunnel=$(cloudflared tunnel info -o json "$tunnel" | jq -r .id)
    dns_record_via_api "$tunnel"
  else
    dns_record_via_cert "$tunnel"
  fi
  sudo systemctl restart cloudflared
}

route_with_api() {
  local token claims account tunnel config
  command -v jq > /dev/null || { echo "jq is needed: sudo apt install jq" >&2; exit 1; }
  : "${CF_API_TOKEN:?the tunnel is managed in the dashboard: set CF_API_TOKEN (Tunnel Edit + DNS Edit)}"

  token=$(grep -oP -- '--token[= ]\K\S+' <<< "$exec_start")
  # The tunnel token is base64 JSON: {"a": account id, "t": tunnel id, "s": secret}.
  claims=$(base64 -d <<< "$token")
  account=$(jq -r .a <<< "$claims")
  tunnel=$(jq -r .t <<< "$claims")
  echo "Tunnel $tunnel (managed in the dashboard)"

  # Replaces any rule for the host, keeping the catch-all last.
  config=$(cf "$api/accounts/$account/cfd_tunnel/$tunnel/configurations" | jq --arg h "$host" --arg s "$service" '
    .result.config
    | .ingress = ((.ingress // [{service: "http_status:404"}]) | map(select(.hostname != $h)))
    | .ingress = .ingress[:-1] + [{hostname: $h, service: $s}] + .ingress[-1:]
    | {config: .}')
  cf -X PUT "$api/accounts/$account/cfd_tunnel/$tunnel/configurations" --data "$config" > /dev/null
  echo "Added $host -> $service"

  dns_record_via_api "$tunnel"
}

if [[ $exec_start == *--token* ]]; then
  route_with_api
else
  route_with_config_file
fi

echo
echo "Checking https://$host (DNS can take a minute to show up)..."
sleep 3
curl -sS -o /dev/null -w "HTTP %{http_code}\n" --max-time 15 "https://$host" \
  || echo "Not reachable yet; try again shortly: curl -I https://$host"
