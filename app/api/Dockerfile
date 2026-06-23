# syntax=docker/dockerfile:1
# ---------- Build stage ----------
# Pinned, minimal base. Multi-stage keeps build toolchain out of the runtime image.
FROM node:22-alpine AS build
WORKDIR /app

# Install dependencies first to leverage Docker layer caching.
COPY package.json package-lock.json ./
# Reproducible install from the lockfile, production dependencies only.
RUN npm ci --omit=dev && npm cache clean --force

# ---------- Runtime stage ----------
FROM node:22-alpine AS runtime
ENV NODE_ENV=production \
    API_PORT=8080
WORKDIR /app

# Drop privileges: create an unprivileged user/group with a fixed UID/GID so the
# Kubernetes securityContext (runAsUser: 10001) maps to the same identity.
RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app -H -s /sbin/nologin app

# Copy only what the service needs to run.
COPY --from=build --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app package.json ./
COPY --chown=app:app src ./src

USER app
EXPOSE 8080

# Container-level healthcheck hitting the liveness endpoint.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:'+(process.env.API_PORT||8080)+'/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "src/server.js"]
