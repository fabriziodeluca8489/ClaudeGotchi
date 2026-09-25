#!/usr/bin/env bash
# Stop: Claude ha finito il turno -> stato "done", poi "idle" dopo 5s.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_common.sh"

INPUT="$(cat)"
SID="$(echo "$INPUT" | jq -r '.session_id // ""')"
TRANSCRIPT="$(echo "$INPUT" | jq -r '.transcript_path // ""')"

read -r CTX OUT <<<"$(cg_tokens "$TRANSCRIPT")"

cg_merge "$SID" "$(jq -nc --argjson ctx "${CTX:-0}" --argjson out "${OUT:-0}" \
  '{state:"done", tool:"", tokens_input:$ctx, tokens_output:$out}')"

# Reset a idle dopo 5s senza bloccare Claude. Solo se ancora "done" (stessa sessione).
(
  sleep 5
  if [ "$(cg_current | jq -r '.state // ""')" = "done" ] \
     && [ "$(cg_current | jq -r '.session_id // ""')" = "$SID" ]; then
    cg_merge "$SID" '{"state":"idle"}'
  fi
) >/dev/null 2>&1 &
disown 2>/dev/null || true
