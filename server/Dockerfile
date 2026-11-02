# The action runner (../runner, given as the build context `runner`):
# Dart compiled on the build machine for the image's architecture, so it does
# not run under QEMU. `docker buildx build --build-context runner=../runner`.
FROM --platform=$BUILDPLATFORM dart:3.12 AS action-runner
ARG TARGETARCH
WORKDIR /runner
COPY --from=runner . .
# `dart compile exe` does not create the folder it writes into.
RUN mkdir -p /out \
 && dart pub get \
 && dart compile exe bin/runner.dart -o /out/action-runner \
      --target-os=linux --target-arch=$([ "$TARGETARCH" = amd64 ] && echo x64 || echo arm64)

# Build stage
FROM node:24-bookworm-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage. Debian, not Alpine: the runner is linked against glibc.
FROM node:24-bookworm-slim AS production
ENV NODE_ENV=production
ENV PORT=3000
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
# Applied on boot, so a deploy is a pull and a restart and nothing else.
COPY drizzle ./drizzle
COPY --from=action-runner /out/action-runner /usr/local/bin/action-runner
ENV ACTION_RUNNER=/usr/local/bin/action-runner

# Everything environment-specific (DATABASE_URL, the Better Auth secret, the
# Google clients) arrives at runtime from the env file next to the compose
# file on the Pi. One image serves every deployment.

EXPOSE 3000
CMD ["node", "dist/main.js"]
