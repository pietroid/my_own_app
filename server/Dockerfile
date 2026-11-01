# Build stage
FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:24-alpine AS production
ENV NODE_ENV=production
ENV PORT=3000
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
# Applied on boot, so a deploy is a pull and a restart and nothing else.
COPY drizzle ./drizzle

# Everything environment-specific (DATABASE_URL, the Better Auth secret, the
# Google clients) arrives at runtime from the env file next to the compose
# file on the Pi. One image serves every deployment.

EXPOSE 3000
CMD ["node", "dist/main.js"]
