#!/usr/bin/env bash
# PreToolUse: Claude sta per eseguire un tool -> stato "working".
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_common.sh"

INPUT="$(cat)"
SID="$(echo "$INPUT" | jq -r '.session_id // ""')"
TOOL="$(echo "$INPUT" | jq -r '.tool_name // ""')"

cg_merge "$SID" "$(jq -nc --arg tool "$TOOL" '{state:"working", tool:$tool}')"
