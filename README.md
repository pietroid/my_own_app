# My Own App

An app to produce any app that you want.

- **App** (`app/`): Flutter, with Google sign-in, a blank home and an
  assistant.
- **Server** (`server/`): NestJS with Better Auth (Google sign-in), Postgres
  on Neon through Drizzle, and the assistant through OpenRouter.

Deployed to a Raspberry Pi as Docker images pulled from GHCR, at
<https://my-own-app.pietroteruya.dev> (replace with your own domain in SETUP.md).

- [SETUP.md](./SETUP.md): local development, Google OAuth, Neon, deployment.
- [AGENTS.md](./AGENTS.md): how the code is organised.
