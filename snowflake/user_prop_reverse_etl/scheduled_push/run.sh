#!/usr/bin/env bash
# Substitute placeholders in scheduled_batch.sql from .env and run via snow CLI.
# Usage: ./run.sh
set -euo pipefail
cd "$(dirname "$0")"

set -a; source .env; set +a

: "${FS_USERS_TABLE:?FS_USERS_TABLE missing in .env (DB.SCHEMA.TABLE)}"
: "${EAI_DATABASE:?EAI_DATABASE missing in .env (DB where the EAI from one_time_push lives)}"
: "${SNOWFLAKE_WAREHOUSE:?SNOWFLAKE_WAREHOUSE missing in .env (warehouse the Task will use)}"
: "${SNOW_CONN:=snowflake}"

TMP=$(mktemp -t scheduled_batch.XXXXXX.sql)
trap 'rm -f "$TMP"' EXIT

sed -e "s|<API-EAI-DB>|${EAI_DATABASE}|g" \
    -e "s|<DATABASE>\.<SCHEMA>\.<USERS_TABLE>|${FS_USERS_TABLE}|" \
    -e "s|<WAREHOUSE>|${SNOWFLAKE_WAREHOUSE}|" \
    scheduled_batch.sql > "$TMP"

snow sql -c "$SNOW_CONN" -f "$TMP"
