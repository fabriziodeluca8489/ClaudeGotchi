import Foundation

// Installa/rimuove gli hook Claude Code. Gli script sono incorporati qui
// (fonte di verità per l'app); la cartella hooks/ del repo serve solo ai test.
// ponytail: script embedded per evitare plumbing di risorse bundle.
enum HookInstaller {
    // Override via CG_CLAUDE_DIR (test in isolamento / relocazione). Default ~/.claude.
    static let claudeDir = ProcessInfo.processInfo.environment["CG_CLAUDE_DIR"]
        ?? ("~/.claude" as NSString).expandingTildeInPath
    static var hooksDir: String { claudeDir + "/tamagotchi-hooks" }
    static var settingsPath: String { claudeDir + "/settings.json" }
    static var bridgePath: String { claudeDir + "/tamagotchi-state.json" }

    struct HookDef { let event, file: String }
    static let defs = [
        HookDef(event: "PreToolUse", file: "pre_tool_use.sh"),
        HookDef(event: "PostToolUse", file: "post_tool_use.sh"),
        HookDef(event: "Stop", file: "stop.sh"),
        HookDef(event: "Notification", file: "notification.sh"),
    ]

    // MARK: - API

    static func install() throws {
        try writeScripts()
        try patchSettings(adding: true)
    }

    static func uninstall() throws {
        try patchSettings(adding: false)
    }

    static func isInstalled() -> Bool {
        guard let json = try? readSettings(),
              let hooks = json["hooks"] as? [String: Any] else { return false }
        for d in defs {
            let arr = hooks[d.event] as? [[String: Any]] ?? []
            if !containsOurs(arr, file: d.file) { return false }
        }
        return true
    }

    // MARK: - Scripts

    private static func writeScripts() throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)
        let files = ["_common.sh": commonSh, "pre_tool_use.sh": preSh,
                     "post_tool_use.sh": postSh, "stop.sh": stopSh,
                     "notification.sh": notificationSh]
        for (name, body) in files {
            let path = hooksDir + "/" + name
            try body.write(toFile: path, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        }
    }

    private static func command(for file: String) -> String {
        "\(hooksDir)/\(file)"
    }

    // MARK: - settings.json patch

    private static func readSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsPath) else { return [:] }
        let data = try Data(contentsOf: URL(fileURLWithPath: settingsPath))
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func containsOurs(_ arr: [[String: Any]], file: String) -> Bool {
        let cmd = command(for: file)
        for group in arr {
            let inner = group["hooks"] as? [[String: Any]] ?? []
            if inner.contains(where: { ($0["command"] as? String) == cmd }) { return true }
        }
        return false
    }

    private static func patchSettings(adding: Bool) throws {
        var json = try readSettings()
        // Backup solo se non esiste già: non sovrascrivere il backup pristino.
        if FileManager.default.fileExists(atPath: settingsPath),
           !FileManager.default.fileExists(atPath: settingsPath + ".bak") {
            try? FileManager.default.copyItem(atPath: settingsPath, toPath: settingsPath + ".bak")
        }
        var hooks = json["hooks"] as? [String: Any] ?? [:]

        for d in defs {
            var arr = hooks[d.event] as? [[String: Any]] ?? []
            let cmd = command(for: d.file)
            // Rimuovi sempre le nostre entry esistenti (evita duplicati).
            arr = arr.compactMap { group -> [String: Any]? in
                var inner = group["hooks"] as? [[String: Any]] ?? []
                inner.removeAll { ($0["command"] as? String) == cmd }
                if inner.isEmpty && (group["hooks"] != nil) { return nil }
                var g = group; g["hooks"] = inner; return g
            }
            if adding {
                arr.append(["hooks": [["type": "command", "command": cmd]]])
            }
            if arr.isEmpty { hooks.removeValue(forKey: d.event) }
            else { hooks[d.event] = arr }
        }

        if hooks.isEmpty { json.removeValue(forKey: "hooks") }
        else { json["hooks"] = hooks }

        let out = try JSONSerialization.data(withJSONObject: json,
                                             options: [.prettyPrinted, .sortedKeys])
        try out.write(to: URL(fileURLWithPath: settingsPath))
    }

    // MARK: - Script incorporati (mirror di hooks/*.sh)

    static let commonSh = #"""
    #!/usr/bin/env bash
    BRIDGE="${CG_BRIDGE:-$HOME/.claude/tamagotchi-state.json}"
    cg_current() {
      if [ -f "$BRIDGE" ] && jq -e . "$BRIDGE" >/dev/null 2>&1; then cat "$BRIDGE"; else echo '{}'; fi
    }
    cg_write() {
      local tmp; tmp="$(mktemp "${BRIDGE}.XXXXXX")"; printf '%s' "$1" > "$tmp"; mv -f "$tmp" "$BRIDGE"
    }
    cg_tokens() {
      local tr="$1"; [ -f "$tr" ] || { echo "0 0"; return; }
      local ctx out
      ctx="$(jq -rs '[ .[] | select(.type=="assistant") | .message.usage | select(. != null) | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0) ] | last // 0' "$tr" 2>/dev/null)"
      out="$(jq -rs '[ .[] | select(.type=="assistant") | .message.usage.output_tokens // 0 ] | add // 0' "$tr" 2>/dev/null)"
      echo "${ctx:-0} ${out:-0}"
    }
    cg_merge() {
      local sid="$1" patch="$2" cur; cur="$(cg_current)"
      local prev_sid; prev_sid="$(echo "$cur" | jq -r '.session_id // ""')"
      if [ "$prev_sid" != "$sid" ]; then cur='{"tool_calls":0}'; fi
      local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      cg_write "$(echo "$cur" | jq --arg sid "$sid" --arg ts "$ts" --argjson patch "$patch" '. + $patch + {session_id:$sid, timestamp:$ts}')"
    }
    """#

    static let preSh = #"""
    #!/usr/bin/env bash
    set -euo pipefail
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/_common.sh"
    INPUT="$(cat)"
    SID="$(echo "$INPUT" | jq -r '.session_id // ""')"
    TOOL="$(echo "$INPUT" | jq -r '.tool_name // ""')"
    cg_merge "$SID" "$(jq -nc --arg tool "$TOOL" '{state:"working", tool:$tool}')"
    """#

    static let postSh = #"""
    #!/usr/bin/env bash
    set -euo pipefail
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/_common.sh"
    INPUT="$(cat)"
    SID="$(echo "$INPUT" | jq -r '.session_id // ""')"
    TRANSCRIPT="$(echo "$INPUT" | jq -r '.transcript_path // ""')"
    read -r CTX OUT <<<"$(cg_tokens "$TRANSCRIPT")"
    PREV_CALLS="$(cg_current | jq -r '.tool_calls // 0')"
    CALLS=$((PREV_CALLS + 1))
    cg_merge "$SID" "$(jq -nc --argjson calls "$CALLS" --argjson ctx "${CTX:-0}" --argjson out "${OUT:-0}" '{state:"working", tool_calls:$calls, tokens_input:$ctx, tokens_output:$out}')"
    """#

    static let stopSh = #"""
    #!/usr/bin/env bash
    set -euo pipefail
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/_common.sh"
    INPUT="$(cat)"
    SID="$(echo "$INPUT" | jq -r '.session_id // ""')"
    TRANSCRIPT="$(echo "$INPUT" | jq -r '.transcript_path // ""')"
    read -r CTX OUT <<<"$(cg_tokens "$TRANSCRIPT")"
    cg_merge "$SID" "$(jq -nc --argjson ctx "${CTX:-0}" --argjson out "${OUT:-0}" '{state:"done", tool:"", tokens_input:$ctx, tokens_output:$out}')"
    ( sleep 5
      if [ "$(cg_current | jq -r '.state // ""')" = "done" ] && [ "$(cg_current | jq -r '.session_id // ""')" = "$SID" ]; then
        cg_merge "$SID" '{"state":"idle"}'
      fi ) >/dev/null 2>&1 &
    disown 2>/dev/null || true
    """#

    static let notificationSh = #"""
    #!/usr/bin/env bash
    set -euo pipefail
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; source "$DIR/_common.sh"
    INPUT="$(cat)"
    SID="$(echo "$INPUT" | jq -r '.session_id // ""')"
    cg_merge "$SID" '{"state":"waiting"}'
    """#
}
