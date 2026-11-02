# Agent Notes

## Project

My Own App: an app to produce any app that you want, built as a Flutter
app (iOS, Android and web) and its NestJS backend, made from the app
template. It starts as sign-in, a blank home and an
assistant; the app is built on top of that.

1. **Flutter app** in `app/`.
2. **NestJS backend** in `server/`: REST API, Better Auth, Postgres.

### Language

Everything the user reads is in **Brazilian Portuguese**. On the app, every
such string lives in `app/packages/l10n/lib/arb/app_pt.arb` and is read
through `context.l10n`. A hardcoded user-facing string in Dart is a bug.
The server writes its own refusals in Portuguese, and the app shows them as
written. Code, comments, commits and this file stay in English.

## Stack

- **App:** Flutter + BLoC + go_router + l10n (ARB, `pt`).
- **Backend:** NestJS 11 + TypeScript + Better Auth + Drizzle ORM.
- **Database:** Postgres on Neon: a `dev` branch locally, `main` in
  production. `npm run db:local` runs an in-memory Postgres (PGlite) for
  working offline.
- **Assistant:** OpenRouter, behind `POST /api/assistant/chat`.
- **Analytics:** PostHog, off until a key is set.
- **Deploy:** two ARM64 images on GHCR (`my-own-app-backend`,
  `my-own-app-web`), pulled by a Raspberry Pi over SSH through a
  Cloudflare tunnel, served at `<your-domain>` (e.g. `my-own-app.pietroteruya.dev`
  or `my-own.app`). See [SETUP.md](./SETUP.md).

## Layout

```
app/
  brand/                icon, Android foreground and splash art (+ README)
  env/                  <flavor>.json defines (examples committed)
  tool/stamp_web.sh     puts the PostHog key in a web build
  lib/                  app (router, AppBloc), home, assistant, apps (renderer, studio)
  packages/
    analytics/          PostHog behind one seam (Analytics, NoAnalytics)
    api_client/         Dio + bearer token interceptor
    app_ui/             the design system: AppBrand, tokens, theme, widgets
    auth/               Better Auth client: Google sign-in, token store
    l10n/               every user-facing string (pt-BR)
runner/                 the actions' interpreter, Dart: compile (server), run (both);
                        third_party/dart_eval, vendored with a step budget
server/
  src/
    analytics/          PostHog: the provider, the route → event table
    apps/               apps as data: bundle rules, the action runner process, routes,
                        edits by tools and versions (edit.ts)
    assistant/          OpenRouter client, the assistant's routes
    auth/               Better Auth instance + SessionGuard
    db/                 Drizzle schema + pool + boot-time migrations
    users/              /users/me
  drizzle/              generated SQL migrations (committed)
deploy/                 docker-compose.yml, nginx.conf, web.Dockerfile
scripts/                Pi and GitHub setup (pi_setup.sh, gh_setup.sh,
                        cloudflare_add_domain.sh)
product/
  spec/                 feature specs kept out of this file
  delivery/             one folder per delivered feature: prompt, design, notes
  improvements/         one folder per /improve run: what changed, evidence, references
  research/             one folder per topic: the RFC (README.md, a deck), its presentation
                        (deck.html, on Pages at research/<folder>/), img/, data/, code/;
                        concepts.md, the ideas every RFC taught
.tool/                  internal tools: check (CI on what changed), preview (prints),
                        cost (session tokens), doc (open/annotate Markdown, RFC slides),
                        queue (GitHub issues worked unattended, gate by gate),
                        review.html (a PR's README on Pages, commented on by selection),
                        deck.html (the shell of an RFC's presentation)
```

## Auth

Better Auth runs inside the Nest server, mounted at `/api/auth/*` in
`main.ts` ahead of Nest's body parser (it reads the raw request itself).
Everything else under `/api` is Nest, protected by `SessionGuard`, which asks
Better Auth for the session behind the request and puts an `AuthUser` on it.

Google is the only way in, by two roads:

- **Web:** the OAuth redirect. `POST /api/auth/sign-in/social` answers with
  Google's URL, the browser leaves, comes back to `/`, and from then on
  sends the session cookie. The web app is served from the same origin as
  the API, so the cookie needs no CORS.
- **iOS/Android:** the native `google_sign_in` SDK produces an ID token
  (minted for the web client, via `serverClientId`), the app posts it to the
  same route, the server verifies it against `GOOGLE_CLIENT_IDS` and answers
  with a session token. The app keeps it in the Keychain/Keystore
  (`TokenStore`) and sends it as `Authorization: Bearer`.

`ALLOWED_EMAILS` gates sign-up: an address not on it never gets a user row.

Better Auth is ESM-only and the server compiles to CommonJS. That works
because Node ≥ 22.12 can `require()` ES modules; keep the images on Node 24.
Code under test must not import `better-auth` at runtime (Jest's CommonJS
sandbox cannot load it): `session.guard.ts` imports only its type.

## The assistant

`POST /api/assistant/chat { messages: [{ role, content }] }` answers
`{ reply }`; the last message is the person's, at most 40 of them. Nothing is
stored: the app keeps the conversation (`AssistantCubit`) and sends all of
it each turn. `GET /api/assistant/status` says whether a model is connected.
Without `OPENROUTER_API_KEY` and `OPENROUTER_MODEL` the chat answers 503 and
everything else works. The system prompt is `systemPrompt` in
`server/src/assistant/assistant.service.ts`; tools go in the second argument
of `OpenRouterClient.generate`.

## Apps as data

The point of the product: the person describes an app, the model builds it
once, and from then on the app runs without the model. An app is a stored
bundle (`generated_app`): `ui`, a flat list of components in our own subset
of A2UI (Column, Row, List, Text, TextField, CheckBox, Button; the one with
id `root` is the screen), bound to `data` by JSON Pointer; `data`, one JSON
document; and `actions`, `Future<List> run(Map input, Map event, Function
call) async` in **Dart**, given only the paths it declares and answering
with a JSON Patch. **Every action runs on the device first**, so a tap
changes the screen at once. An action is `on` `"server"` (the default:
saved; after showing its patch the app sends the tap to the server, one at
a time and in order, which runs the same action on its own copy and keeps
the patch; a different answer or a refusal reloads the server's copy) or
`"client"` (screen-only, never sent). A client action may `await call(name,
event)` a saved one, which works the same way. What a person types lives
only on the device, so a saved action reads it from the event (a button's
`context`), never from `input`.

- `POST /api/apps { prompt }` is one forced `create_app` tool call (and one
  retry with the error), checked by `parseBundle`. The prompt is
  `BUILD_PROMPT` in `server/src/apps/apps.service.ts`.
- **One interpreter, both sides:** `runner/` (`action_runner`) wraps a
  vendored dart_eval 0.8.5 with a **step budget** (`runner/third_party/`,
  every change marked `my_own_app:`). `compile.dart` turns an action into
  bytecode (server only: it brings the analyzer); `run.dart` runs bytecode
  with no files, network or processes, and stops it past 2M steps. The app
  and the server must use the same copy: bytecode is not portable
  (`runnerVersion`).
- The server compiles every action when the app is built (a compile error
  goes back to the model in the retry) and stores `evc` and `version` next
  to `code`; bytecode an older runner wrote is recompiled when the app is
  read. It runs them in **one Dart process** beside Nest (`ActionRunner`,
  `server/src/apps/runner.ts`), spoken to in JSON lines, heap capped
  (`ACTION_RUNNER_HEAP_MB`), restarted if it dies or hangs.
- `POST /api/apps/:id/actions/:name { event }` runs the action there,
  applies the patch under a `rev` check and answers it as an AG-UI
  `STATE_DELTA`; the app applies the same patch. It refuses a client action.
- `GET /api/apps/:id` sends every action's bytecode (`actions: { name: {
  on, input, evc } }`); no action's source leaves the server.
- The app runs actions with the same `run.dart`, on the web, iOS and
  Android alike (`app/lib/apps/client_runner.dart`), on the main isolate:
  the step budget is what keeps a runaway action from freezing it.
  `AppRunCubit` holds the local-first rules.
- The whole contract, the runner's protocol and its limits:
  [product/spec/actions.md](./product/spec/actions.md).
- On a window at least `AppSpacing.phoneFrameBreakpoint` wide, the app runs
  inside `AppPhoneFrame`.
- The app draws it with `AppRenderer` (`app/lib/apps/`). A component it
  does not know draws nothing; a new one goes in both `COMPONENTS` and the
  renderer, and in `BUILD_PROMPT`.

### The studio: changing an app

A built app opens beside the conversation that changes it (and, on a wide
window, an inspector where any component can be picked and made the
subject of a request). Every request is a **version** (`app_version`: the
request, the reply, the app right after); any version can be looked at and
brought back. `POST /api/apps/:id/messages` changes the app with **tools**
(`server/src/apps/edit.ts`, `EDIT_PROMPT`): the model sees the screen and
the data, but the actions only by name; it reads one with `read_action`
and writes one with `set_action` only when its code must change, so only
those are recompiled. Spec: [product/spec/studio.md](./product/spec/studio.md).

## The design system

Screens draw only with `app_ui`: colours from `AppColors`, type from
`AppTypography`, gaps and radii from `AppSpacing`, icons from `AppIcons`. A
value a screen needs that is not a token becomes a new token, never a
literal. The look is restyled by the `/design-system` skill.

## Analytics

PostHog hears of each write that succeeded, by route, from
`LoggingInterceptor`; of every 5xx and crash; of the screens; and records
replays with every text and image masked. **Nothing a person wrote is ever
sent**, and **without `POSTHOG_KEY` nothing is sent at all**. A new write
route gets its row in `server/src/analytics/events.ts`. In the app only
`packages/analytics` calls the plugin; tests use `NoAnalytics`.

## The queue

Work reaches the repo as GitHub issues labelled `create`, `research` or
`improve` (the issue templates add them), worked by `.tool/queue` on the
Mac: each phase a headless Claude in its own worktree and branch, stopping
at each gate with a comment and a push to the phone; "approve" alone goes
on, anything else is feedback. The skills it runs are `/create`,
`/research` and `/improve`. See [.tool/README.md](./.tool/README.md).

## Commands

```bash
.tool/check             # CI's checks on what changed (--all: everything)

# Server
cd server
npm run runner:build    # the action runner (Dart); start:local and npm test do it too
npm run db:local        # optional: in-memory Postgres on :5433
npm run start:local     # watches; needs server/.env.local (see .env.example)
npm test
npm run db:generate     # after editing src/db/schema.ts; commit drizzle/
npm run apps:rebuild    # after a build: rebuild apps whose actions were never compiled
                        # (-- --all: every app, from fresh data, after BUILD_PROMPT changed)

# Action runner (Dart, used by the server and the app)
cd runner && dart test && dart test -p chrome

# App
cd app
flutter run --flavor dev --dart-define-from-file env/dev.json
flutter run -d chrome --web-port 5173 --dart-define-from-file env/dev.json
flutter test
(cd packages/l10n && flutter gen-l10n)   # after editing app_pt.arb; commit gen/
dart run flutter_launcher_icons          # after changing brand/
dart run flutter_native_splash:create
```

Migrations run on server boot (`migrateDatabase` in `main.ts`), so there is
no separate migrate step in deployment.
