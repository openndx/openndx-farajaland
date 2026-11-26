# shellcheck shell=bash
# Reads settings from ndx/.env, the file Docker Compose reads for the NDX stack.
# Sourced by init.sh and members/run-member-services.sh, so a value changed in
# ndx/.env reaches the containers and these scripts alike.
#
# Usage: . scripts/settings.sh; setting NAME default
#
# setting sets NAME from the environment if it is set there, otherwise from
# ndx/.env, otherwise to the given default. As in Docker Compose, a value in
# single or double quotes keeps everything between its quotes, and an unquoted
# value ends at " #" (an inline comment).

NDX_ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/ndx/.env"

setting() {
    local name=$1 default=$2 value=""
    if [ -n "${!name+x}" ]; then
        value=${!name}
    elif [ -f "$NDX_ENV_FILE" ]; then
        value=$(tr -d '\r' < "$NDX_ENV_FILE" | sed -n "s/^${name}=//p" | tail -n 1 |
            sed -E -e "s/^'([^']*)'.*\$/\\1/" -e 't' -e 's/^"([^"]*)".*$/\1/' -e 't' \
                -e 's/[[:space:]]+#.*$//' -e 's/[[:space:]]+$//')
    fi
    printf -v "$name" '%s' "${value:-$default}"
}
