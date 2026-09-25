#!/usr/bin/env bash
# Funzioni condivise dagli hook ClaudeGotchi.
# Bridge file letto dall'app via FSEvents.

# Sovrascrivibile via CG_BRIDGE (usato dai test per isolamento).
BRIDGE="${CG_BRIDGE:-$HOME/.claude/tamagotchi-state.json}"

# Legge il bridge file corrente, o {} se assente/corrotto.
cg_current() {
  if [ -f "$BRIDGE" ] && jq -e . "$BRIDGE" >/dev/null 2>&1; then
    cat "$BRIDGE"
  else
    echo '{}'
  fi
}

# Scrittura atomica: tmp nella stessa dir + mv (l'app riapre l'fd sul rename).
cg_write() {
  local tmp
  tmp="$(mktemp "${BRIDGE}.XXXXXX")"
  printf '%s' "$1" > "$tmp"
  mv -f "$tmp" "$BRIDGE"
}

# Estrae dal transcript JSONL i token: contesto (ultimo msg) e output cumulativo.
# Stampa "context_tokens output_tokens". "0 0" se transcript assente.
cg_tokens() {
  local tr="$1"
  [ -f "$tr" ] || { echo "0 0"; return; }
  # Contesto = input + cache dell'ultimo messaggio assistant con usage.
  local ctx out
  ctx="$(jq -rs '
    [ .[] | select(.type=="assistant") | .message.usage
      | select(. != null)
      | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0) ]
    | last // 0' "$tr" 2>/dev/null)"
  out="$(jq -rs '
    [ .[] | select(.type=="assistant") | .message.usage.output_tokens // 0 ]
    | add // 0' "$tr" 2>/dev/null)"
  echo "${ctx:-0} ${out:-0}"
}

# Merge dei campi passati (JSON object) nel bridge, gestendo reset per sessione.
# $1 = session_id, $2 = JSON object con i campi da sovrascrivere.
cg_merge() {
  local sid="$1" patch="$2" cur
  cur="$(cg_current)"
  # Reset contatori se cambia sessione.
  local prev_sid
  prev_sid="$(echo "$cur" | jq -r '.session_id // ""')"
  if [ "$prev_sid" != "$sid" ]; then
    cur='{"tool_calls":0}'
  fi
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cg_write "$(echo "$cur" | jq \
    --arg sid "$sid" --arg ts "$ts" --argjson patch "$patch" \
    '. + $patch + {session_id:$sid, timestamp:$ts}')"
}
