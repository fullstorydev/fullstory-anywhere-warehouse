#!/usr/bin/env bash
# Substitute placeholders in simple_batch.sql from .env and run via snow CLI.
# Usage: ./run.sh
set -euo pipefail
cd "$(dirname "$0")"

set -a; source .env; set +a

: "${FS_API_KEY:?FS_API_KEY missing in .env}"
: "${FS_USERS_TABLE:?FS_USERS_TABLE missing in .env (DB.SCHEMA.TABLE)}"
: "${EAI_DATABASE:?EAI_DATABASE missing in .env (writable DB for EAI objects)}"
: "${SNOW_CONN:=snowflake}"

TMP=$(mktemp -t simple_batch.XXXXXX.sql)
trap 'rm -f "$TMP"' EXIT

sed -e "s|<API-EAI-DB>|${EAI_DATABASE}|g" \
    -e "s|<YOUR_FULLSTORY_SERVER_API_KEY>|${FS_API_KEY}|" \
    -e "s|<DATABASE>\.<SCHEMA>\.<USERS_TABLE>|${FS_USERS_TABLE}|" \
    simple_batch.sql > "$TMP"

snow sql -c "$SNOW_CONN" -f "$TMP"
