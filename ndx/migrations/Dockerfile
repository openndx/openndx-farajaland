# Database migrator for the Farajaland stack: the migrate command from
# OpenNSW/tools (https://github.com/OpenNSW/tools/tree/main/migrator) on a
# postgres image, whose psql run.sh uses to create each service's database and
# load the demo seed data.
#
# The SQL is not baked in: compose mounts ndx/migrations at /migrations, so
# editing a migration or seed needs no rebuild.

# The migrator is built on the build machine's platform and cross-compiled
# for the target, so a multi-arch build fetches the module once.
FROM --platform=$BUILDPLATFORM golang:1.27-alpine3.24 AS migrate-builder

RUN apk add --no-cache git
WORKDIR /tmp-build
RUN GOWORK=off go mod init migrate-build

# A release of OpenNSW/tools' migrator (tags migrator/v*). It replaces the
# same tool from OpenNSW/agency, which is being archived: same commands,
# migration file format and __migrations table. Override with
#   MIGRATE_VERSION=<version> docker compose build migrate
ARG MIGRATE_PACKAGE=github.com/OpenNSW/tools/migrator/cmd/migrate
ARG MIGRATE_VERSION=v0.1.0
RUN GOWORK=off go get ${MIGRATE_PACKAGE}@${MIGRATE_VERSION}

ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOWORK=off \
    go build -ldflags="-s -w" -o /out/migrate ${MIGRATE_PACKAGE}

# The same major version as the postgres service, so psql matches the server.
FROM postgres:15-alpine

COPY --from=migrate-builder /out/migrate /usr/local/bin/migrate

WORKDIR /migrations
# Through sh, so run.sh needs no executable bit on the mounted checkout.
ENTRYPOINT ["/bin/sh", "/migrations/run.sh"]
CMD ["up"]
