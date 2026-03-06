#!/bin/sh
set -e

echo "Starting phirepass-agent with custom configuration..."

if [ -f /secrets/access_token.txt ]; then
    export PAT_TOKEN=$(cat /secrets/access_token.txt)
    echo "Access token loaded from file"
elif [ -f /secrets/pat_token.txt ]; then
    export PAT_TOKEN=$(cat /secrets/pat_token.txt)
    echo "PAT token loaded from file"
fi

if [ -n "${PAT_TOKEN}" ]; then
    echo "${PAT_TOKEN}" | /app/agent login --from-stdin --server-host "${SERVER_HOST}" --server-port "${SERVER_PORT}"
else
    echo "PAT_TOKEN is empty; please provide a token for agent to login."
fi

exec /app/agent start
