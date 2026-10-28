# Build Stage for Client
FROM node:20-alpine AS client-build
WORKDIR /app/client
COPY client/package*.json ./
RUN npm ci
COPY client/ .
# The frontend uses the local demo login and needs no identity-provider settings.
RUN npm run build

# Build Stage for Server
FROM node:20-alpine AS server-build
WORKDIR /app/server
COPY server/package*.json ./
RUN npm ci
COPY server/ .
RUN npm run build

# Final Stage
FROM node:20-alpine
WORKDIR /app

# Copy server built files
COPY --from=server-build /app/server/dist ./server/dist
COPY --from=server-build /app/server/package*.json ./server/
COPY --from=server-build /app/server/node_modules ./server/node_modules

# Copy client built files to the location expected by server (../../client/dist relative to server/dist/index.js)
# Server is running at /app/server, so index is at /app/server/dist/index.js
# It looks for ../../client/dist -> /app/client/dist
COPY --from=client-build /app/client/dist ./client/dist

WORKDIR /app/server
ENV PORT=3000
EXPOSE 3000

CMD ["node", "dist/index.js"]
