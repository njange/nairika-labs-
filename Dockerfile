FROM node:22-slim AS build
WORKDIR /app

COPY package.json package-lock.json ./
# Lovable manages deps with bun, so package-lock.json drifts; npm ci would refuse it.
RUN npm install --no-audit --no-fund

COPY . .
# VITE_* values are baked into the client bundle at build time.
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_PUBLISHABLE_KEY
ARG VITE_SUPABASE_PROJECT_ID
RUN NITRO_PRESET=node-server npm run build

FROM node:22-slim
WORKDIR /app
ENV NODE_ENV=production PORT=3000 HOST=0.0.0.0
COPY --from=build /app/.output ./.output
USER node
EXPOSE 3000
CMD ["node", ".output/server/index.mjs"]
