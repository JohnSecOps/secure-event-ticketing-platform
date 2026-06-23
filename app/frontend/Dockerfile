# syntax=docker/dockerfile:1
# ---------- Build stage ----------
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---------- Runtime stage ----------
FROM node:22-alpine AS runtime
ENV NODE_ENV=production \
    FRONTEND_PORT=3000
WORKDIR /app

RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app -H -s /sbin/nologin app

COPY --from=build --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app package.json ./
COPY --chown=app:app src ./src

USER app
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:'+(process.env.FRONTEND_PORT||3000)+'/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "src/server.js"]
