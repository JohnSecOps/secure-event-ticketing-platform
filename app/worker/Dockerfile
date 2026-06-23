# syntax=docker/dockerfile:1
# ---------- Build stage ----------
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---------- Runtime stage ----------
FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app

RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx && addgroup -S -g 10001 app && adduser -S -u 10001 -G app -H -s /sbin/nologin app

COPY --from=build --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app package.json ./
COPY --chown=app:app src ./src

USER app

# The worker is a queue consumer with no HTTP port; liveness is process-based.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD pgrep -f "src/worker.js" >/dev/null || exit 1

CMD ["node", "src/worker.js"]
