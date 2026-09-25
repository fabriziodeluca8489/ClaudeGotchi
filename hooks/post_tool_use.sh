#!/usr/bin/env bash
# PostToolUse: tool finito -> incrementa contatore, aggiorna token dal transcript.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_common.sh"

INPUT="$(cat)"
SID="$(echo "$INPUT" | jq -r '.session_id // ""')"
TRANSCRIPT="$(echo "$INPUT" | jq -r '.transcript_path // ""')"

read -r CTX OUT <<<"$(cg_tokens "$TRANSCRIPT")"

# tool_calls incrementato leggendo lo stato corrente.
PREV_CALLS="$(cg_current | jq -r '.tool_calls // 0')"
CALLS=$((PREV_CALLS + 1))

cg_merge "$SID" "$(jq -nc \
  --argjson calls "$CALLS" --argjson ctx "${CTX:-0}" --argjson out "${OUT:-0}" \
  '{state:"working", tool_calls:$calls, tokens_input:$ctx, tokens_output:$out}')"
