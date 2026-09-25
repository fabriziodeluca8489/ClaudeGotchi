#!/usr/bin/env bash
# Notification: Claude chiede un permesso o attende input -> stato "waiting".
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_common.sh"

INPUT="$(cat)"
SID="$(echo "$INPUT" | jq -r '.session_id // ""')"

cg_merge "$SID" '{"state":"waiting"}'
