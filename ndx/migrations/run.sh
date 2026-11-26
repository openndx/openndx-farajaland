#!/bin/sh
# Database setup for the Farajaland stack, run by the `migrate` compose service
# before the services that use the databases start:
#   1. creates each service's database if it is missing;
#   2. applies each service's pending migrations from ndx/migrations/<service>/
#      with the migrate tool, which records them in that database's
#      __migrations table;
#   3. loads the demo seed data. Seeds insert only rows that are missing, so
#      re-running them never overwrites a row changed through a service's API.
#
# Usage, from ndx/:
#   docker compose run --rm migrate               # same as `up`, what compose runs
#   docker compose run --rm migrate status        # applied/pending, per service
#   docker compose run --rm migrate down pdp|ce   # roll back that service's last migration
set -eu

usage() {
  echo "usage: run.sh [up | status | down <pdp|ce>]" >&2
}

: "${DB_HOST:?}" "${DB_PORT:?}" "${DB_USER:?}" "${DB_PASSWORD:?}" "${DB_SSLMODE:?}"
: "${PDP_DB_NAME:?}" "${CE_DB_NAME:?}" "${AUDIT_DB_NAME:?}"

# The migrate tool reads config.yaml, which takes its values from the
# environment; psql reads the PG* variables.
export CONFIG_PATH=/migrations/config.yaml
export PGHOST="$DB_HOST" PGPORT="$DB_PORT" PGUSER="$DB_USER" PGPASSWORD="$DB_PASSWORD" PGSSLMODE="$DB_SSLMODE"

# The services with migrations, and their databases. The audit service
# (argus) creates its own tables, so it only needs its database.
SERVICES="pdp ce"
database_of() {
  case "$1" in
    pdp) echo "$PDP_DB_NAME" ;;
    ce) echo "$CE_DB_NAME" ;;
    *) echo "run.sh: unknown service '$1', expected one of: $SERVICES" >&2; return 1 ;;
  esac
}

# CREATE DATABASE can't run inside a transaction or a DO block, hence \gexec.
create_database() {
  psql -d postgres -v ON_ERROR_STOP=1 -q -v db="$1" <<'SQL'
SELECT format('CREATE DATABASE %I', :'db')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db')\gexec
SQL
}

# $1: service, $2: migrate command (up, status, down)
migrate_service() {
  db=$(database_of "$1")
  echo "== $1 migrations ($db)"
  MIGRATE_DB_NAME="$db" MIGRATE_DIR="/migrations/$1" migrate "$2"
}

seed() {
  : "${DEMO_ACCESS_GRANT_TTL:?}"
  echo "== pdp demo seed ($PDP_DB_NAME, access grant TTL: $DEMO_ACCESS_GRANT_TTL)"
  psql -d "$PDP_DB_NAME" -v ON_ERROR_STOP=1 -v access_grant_ttl="$DEMO_ACCESS_GRANT_TTL" \
    -f /migrations/pdp/seed/demo.sql
}

case "${1:-up}" in
  up)
    for db in "$PDP_DB_NAME" "$CE_DB_NAME" "$AUDIT_DB_NAME"; do
      create_database "$db"
    done
    for svc in $SERVICES; do
      migrate_service "$svc" up
    done
    seed
    ;;
  status)
    for svc in $SERVICES; do
      migrate_service "$svc" status
    done
    ;;
  down)
    if [ $# -lt 2 ]; then
      usage
      exit 1
    fi
    migrate_service "$2" down
    ;;
  *)
    usage
    exit 1
    ;;
esac
