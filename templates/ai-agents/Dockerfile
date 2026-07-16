# supy-ai-agents container — non-root runtime (architecture.md rule 6).
# Model for a Node service (e.g. Cortex). Multi-stage: build as usual, but the RUNTIME stage drops to
# a non-root UID (1001) matching the repo's existing container convention. Adapt the base image /
# build steps per package; the non-root USER directive is the load-bearing part.

# --- build stage ---
FROM node:20-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# --- runtime stage ---
FROM node:20-slim AS runtime
WORKDIR /app

# Create an unprivileged user/group and own the app dir as it.
RUN groupadd -g 1001 app && useradd -u 1001 -g app -m app

COPY --chown=app:app package*.json ./
RUN npm ci --omit=dev
COPY --chown=app:app --from=build /app/dist ./dist

# Secrets are injected as env at runtime (never baked into the image) — architecture.md rule 1.
USER app                                   # rule 6: never run the runtime as root
CMD ["node", "dist/server.js"]
