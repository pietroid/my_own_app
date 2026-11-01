# Setup

The setup CLI (in the app template) does all of this for a new app and
prints what is left. This is what it does, for doing any of it again by
hand.

## 1. Neon

A Neon project (region **AWS São Paulo, `sa-east-1`**, next to the Pi) with
two branches: `main` for production, `dev` for local work. Each branch's
connection string ends in `?sslmode=require`. The schema is created by the
server itself: migrations in `server/drizzle/` run on every boot.

## 2. Google OAuth

One Google Cloud project for the app, so the consent screen names it. Under
**APIs & Services → Credentials**:

1. **Web client** (type *Web application*):

   | | |
   |---|---|
   | JavaScript origins | `https://<your-domain>`, `http://localhost:5173`, `http://localhost:3000` |
   | Redirect URIs | `https://<your-domain>/api/auth/callback/google`, `http://localhost:3000/api/auth/callback/google` |

   Its secret goes to the server only.
2. **iOS client** for `com.<your-prefix>.<app>`, and another for
   `com.<your-prefix>.<app>.dev`.
3. **Android client** for each package (the same two), with your keystore's
   SHA-1 (`cd app/android && ./gradlew signingReport`).

Then:

- `server/.env*` and the Pi's `.env`: `GOOGLE_CLIENT_IDS` (the web client
  first, then each iOS client) and `GOOGLE_CLIENT_SECRET`.
- `app/env/<flavor>.json`: `GOOGLE_WEB_CLIENT_ID` and that flavor's
  `GOOGLE_IOS_CLIENT_ID`.
- `app/ios/Flutter/GoogleSignIn.xcconfig`: each iOS client ID reversed
  (`com.googleusercontent.apps.<id>`), the URL scheme Google returns to.

## 3. Local development

```bash
# Server
cd server
cp .env.example .env.local      # fill DATABASE_URL (Neon dev), secrets, Google
npm install
npm run start:local             # http://localhost:3000/api

# App (another terminal)
cd app
cp env/dev.example.json env/dev.json
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define-from-file env/dev.json
flutter run --flavor dev --dart-define-from-file env/dev.json   # phone/simulator
```

On the web the dev server must run on **5173**: it is the origin the server
trusts (`TRUSTED_ORIGINS`) and Google redirects back to. On a physical
phone, `API_BASE_URL` must be your machine's LAN address
(`http://192.168.x.x:3000/api`), not `localhost`.

## 4. The Raspberry Pi

The Pi runs two containers from GHCR, in `/opt/<app>`:

- `<app>-backend`: the API, published on the Pi's loopback only
  (`curl localhost:$BACKEND_PORT/api/health` there);
- `<app>-web`: nginx serving the Flutter web build and proxying `/api`
  to the backend, on `WEB_PORT`, which the Cloudflare tunnel routes
  `<your-domain>` to.

`/opt/<app>/.env` is the server's production env (see
`server/.env.example`, with `BETTER_AUTH_URL=https://<your-domain>`)
plus `WEB_PORT` and `BACKEND_PORT`. `scripts/pi_setup.sh` installs it, checks
the ports and adds the tunnel's hostname (`scripts/cloudflare_add_domain.sh`):

```bash
scp scripts/pi_setup.sh scripts/cloudflare_add_domain.sh server.env focus:
ssh -t focus ./pi_setup.sh <app> <web port> <backend port> <your-domain> server.env
```

To roll back, set `APP_TAG=<commit sha>` (one of the five kept) in the
`.env` and run `docker compose up -d`.

## 5. DNS and the Cloudflare Tunnel

The public domain can be either an apex (`my-own.app`) or a subdomain
(`app.my-own.app`).

**Apex (`my-own.app`)**

- The Cloudflare tunnel creates a CNAME record at the apex. Cloudflare
  supports CNAME flattening for apex domains, so this works on a
  proxied (orange-cloud) record.
- Google OAuth JavaScript origin and redirect URI must be exactly
  `https://my-own.app` and `https://my-own.app/api/auth/callback/google`.
- `BETTER_AUTH_URL` and the app's `API_BASE_URL` must also use
  `https://my-own.app`.

**Subdomain (`app.my-own.app`)**

- Easier if you already use the apex for something else. The tunnel
  creates a proxied CNAME from `app.my-own.app` to
  `<tunnel-id>.cfargotunnel.com`.
- Google OAuth, `BETTER_AUTH_URL` and `API_BASE_URL` all use
  `https://app.my-own.app`.

**Setting it up**

1. Add the domain to your Cloudflare account (Nameservers or CNAME setup).
2. Create a Cloudflare Tunnel: **Zero Trust → Networks → Tunnels** → Create
   tunnel. Copy the tunnel token.
3. Install `cloudflared` on the Pi and run it with the token:
   ```bash
   cloudflared service install <token>
   ```
   Or manage the tunnel in the dashboard and let `cloudflare_add_domain.sh`
   edit it through the API (it needs `CF_API_TOKEN` with Zone > DNS > Edit
   and Account > Cloudflare Tunnel > Edit).
4. Run `scripts/cloudflare_add_domain.sh <your-domain> <web-port>` on the
   Pi. It adds the ingress rule and the DNS record.
5. Wait for DNS, then `curl -I https://<your-domain>` should hit the Pi.

## 6. GitHub

`.github/workflows/deploy.yml` runs on every push to `main`: tests, and once
the variable `DEPLOY` is `true`, builds both images for ARM64, pushes them to
`ghcr.io/<owner>/`, SSHes to the Pi through the tunnel and runs
`docker compose pull && docker compose up -d`.

`scripts/gh_setup.sh` sets the deploy's secrets and variables from
`~/.config/pi-deploy/deploy.env` and the Pi's own deploy key:

| | |
|---|---|
| Secrets | `PI_SSH_PRIVATE_KEY`, `TUNNEL_SERVICE_TOKEN_ID`, `TUNNEL_SERVICE_TOKEN_SECRET` |
| Variables | `PI_USER`, `CLOUDFLARE_SSH_HOSTNAME`, `POSTHOG_KEY` (optional), `DEPLOY` |

Keep the images **private** (your profile → Packages → each image →
Package settings).

## 7. PostHog

Optional, and off until its key is set. The project key (`phc_…`) goes in
the server's `POSTHOG_KEY`, the repository variable `POSTHOG_KEY` (the web
build) and `app/env/production.json` (the phones). In the project's
settings: session replay and canvas capture on, heatmaps and autocapture
off, error tracking on.

## Mobile builds

```bash
cd app
flutter build ipa --flavor production --dart-define-from-file env/production.json
flutter build appbundle --flavor production --dart-define-from-file env/production.json
```
