#!/usr/bin/env bash
# Self-check hook: esegue gli script con payload finti in un bridge isolato
# e verifica che il risultato sia JSON valido e coerente.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export CG_BRIDGE="$TMP/state.json"

# Transcript finto: 2 messaggi assistant con usage.
TR="$TMP/transcript.jsonl"
cat > "$TR" <<'EOF'
{"type":"assistant","message":{"usage":{"input_tokens":100,"cache_read_input_tokens":900,"cache_creation_input_tokens":0,"output_tokens":50}}}
{"type":"assistant","message":{"usage":{"input_tokens":200,"cache_read_input_tokens":1800,"cache_creation_input_tokens":0,"output_tokens":80}}}
EOF

SID="test-session-1"
fail() { echo "FAIL: $1"; exit 1; }
val() { jq -r "$1" "$CG_BRIDGE"; }

# --- PreToolUse ---
echo "{\"session_id\":\"$SID\",\"tool_name\":\"Bash\"}" | bash "$DIR/pre_tool_use.sh"
jq -e . "$CG_BRIDGE" >/dev/null || fail "pre: JSON non valido"
[ "$(val .state)" = "working" ] || fail "pre: state != working"
[ "$(val .tool)" = "Bash" ] || fail "pre: tool != Bash"
[ "$(val .session_id)" = "$SID" ] || fail "pre: session_id errato"

# --- PostToolUse x2 ---
echo "{\"session_id\":\"$SID\",\"transcript_path\":\"$TR\"}" | bash "$DIR/post_tool_use.sh"
echo "{\"session_id\":\"$SID\",\"transcript_path\":\"$TR\"}" | bash "$DIR/post_tool_use.sh"
[ "$(val .tool_calls)" = "2" ] || fail "post: tool_calls != 2 (ho $(val .tool_calls))"
# contesto = ultimo msg: 200+1800+0 = 2000
[ "$(val .tokens_input)" = "2000" ] || fail "post: context != 2000 (ho $(val .tokens_input))"
# output cumulativo = 50+80 = 130
[ "$(val .tokens_output)" = "130" ] || fail "post: output != 130 (ho $(val .tokens_output))"

# --- Notification (permesso richiesto) ---
echo "{\"session_id\":\"$SID\",\"message\":\"Claude needs your permission\"}" | bash "$DIR/notification.sh"
[ "$(val .state)" = "waiting" ] || fail "notification: state != waiting"
[ "$(val .tool_calls)" = "2" ] || fail "notification: tool_calls perso"

# --- Stop ---
echo "{\"session_id\":\"$SID\",\"transcript_path\":\"$TR\"}" | bash "$DIR/stop.sh"
[ "$(val .state)" = "done" ] || fail "stop: state != done"

# --- Reset sessione ---
echo "{\"session_id\":\"other-session\",\"tool_name\":\"Read\"}" | bash "$DIR/pre_tool_use.sh"
[ "$(val .tool_calls)" = "0" ] || fail "reset: tool_calls non azzerato su nuova sessione (ho $(val .tool_calls))"

echo "OK: tutti i check hook passati"
