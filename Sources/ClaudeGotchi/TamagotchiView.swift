import SwiftUI

// Personaggi disponibili, selezionabili dal menu contestuale.
enum Skin: String, CaseIterable, Identifiable {
    case dev, bot, star
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dev: return "Sviluppatore"
        case .bot: return "Robot"
        case .star: return "Star Puccioso"
        }
    }
    // Prefisso dei file sprite del personaggio (es. "robot_idle_1x8.png").
    var spritePrefix: String {
        switch self {
        case .dev: return ""
        case .bot: return "robot_"
        case .star: return "star_"
        }
    }
}

func cgTint(_ s: CGState) -> Color {
    switch s {
    case .idle: return Color(red: 0.30, green: 0.78, blue: 0.70)
    case .working: return Color(red: 0.32, green: 0.55, blue: 0.95)
    case .waiting: return Color(red: 0.95, green: 0.65, blue: 0.25)
    case .done: return Color(red: 0.35, green: 0.80, blue: 0.40)
    case .error: return Color(red: 0.90, green: 0.35, blue: 0.35)
    }
}

enum SizePreset: String, CaseIterable, Identifiable {
    case small, medium, large, xlarge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .small: return "Piccolo"
        case .medium: return "Medio"
        case .large: return "Grande"
        case .xlarge: return "Molto grande"
        }
    }
    var scale: CGFloat {
        switch self {
        case .small: return 0.75
        case .medium: return 1.0
        case .large: return 1.5
        case .xlarge: return 2.0
        }
    }
}

enum BGColor: String, CaseIterable, Identifiable {
    case stato, notte, nebbia
    var id: String { rawValue }
    var label: String {
        switch self {
        case .stato:  return "Stato"
        case .notte:  return "Notte"
        case .nebbia: return "Nebbia"
        }
    }
    func color(_ state: CGState) -> Color {
        switch self {
        case .stato:  return cgTint(state)
        case .notte:  return Color(red: 0.08, green: 0.08, blue: 0.14)
        case .nebbia: return Color(red: 0.88, green: 0.88, blue: 0.92)
        }
    }
}

// Informazioni selezionabili in dashboard.
enum InfoField: String, CaseIterable, Identifiable {
    case caption, tool, ctxTokens, outTokens, toolCalls, limit5h, limit7d, ctxPct, model
    var id: String { rawValue }
    var label: String {
        switch self {
        case .caption:   return "Didascalia stato"
        case .tool:      return "Nome tool in uso"
        case .ctxTokens: return "Token contesto"
        case .outTokens: return "Token output"
        case .toolCalls: return "Tool calls"
        case .limit5h:   return "Limite 5h"
        case .limit7d:   return "Limite 7 giorni"
        case .ctxPct:    return "Contesto %"
        case .model:     return "Modello"
        }
    }
    // Campi mostrati come righe statistiche (gli altri compongono la didascalia).
    var isStat: Bool { self != .caption && self != .tool }
    static let defaults: Set<InfoField> = [.caption, .tool, .limit5h, .limit7d, .ctxPct]
}

final class Settings: ObservableObject {
    @AppStorage("selectedSkin") private var skinRaw = Skin.dev.rawValue
    @AppStorage("selectedSize") private var sizeRaw = SizePreset.medium.rawValue
    @AppStorage("showStats") private var showStatsRaw: Bool = true
    @AppStorage("bgTransparent") private var bgTransparentRaw: Bool = true
    @AppStorage("bgColorRaw") private var bgColorRaw = BGColor.stato.rawValue
    // Mappe attività -> sheet/fps e campi info, salvate come JSON.
    @AppStorage("animSheets") private var animSheetsRaw = "{}"
    @AppStorage("animFps") private var animFpsRaw = "{}"
    @AppStorage("infoFields") private var infoFieldsRaw = ""
    @AppStorage("statsAlways") private var statsAlwaysRaw = false
    @AppStorage("sleepMinutes") private var sleepMinutesRaw = 10.0

    var skin: Skin {
        get { Skin(rawValue: skinRaw) ?? .dev }
        set { skinRaw = newValue.rawValue; objectWillChange.send() }
    }
    var sizePreset: SizePreset {
        get { SizePreset(rawValue: sizeRaw) ?? .medium }
        set { sizeRaw = newValue.rawValue; objectWillChange.send() }
    }
    var bgColor: BGColor {
        get { BGColor(rawValue: bgColorRaw) ?? .stato }
        set { bgColorRaw = newValue.rawValue; objectWillChange.send() }
    }
    var showStats: Bool {
        get { showStatsRaw }
        set { showStatsRaw = newValue; objectWillChange.send() }
    }
    var bgTransparent: Bool {
        get { bgTransparentRaw }
        set { bgTransparentRaw = newValue; objectWillChange.send() }
    }
    var statsAlways: Bool {
        get { statsAlwaysRaw }
        set { statsAlwaysRaw = newValue; objectWillChange.send() }
    }
    var sleepMinutes: Double {
        get { sleepMinutesRaw }
        set { sleepMinutesRaw = newValue; objectWillChange.send() }
    }

    // Scelte per attività salvate per personaggio: chiave "<prefisso><attività>".
    private func key(_ a: Activity) -> String { skin.spritePrefix + a.rawValue }

    func sheet(for a: Activity) -> SheetDef {
        let map: [String: String] = decode(animSheetsRaw) ?? [:]
        let p = skin.spritePrefix
        return map[key(a)].flatMap(SheetDef.named)
            ?? SheetDef.named(p + a.defaultSheet) ?? SheetDef.named(p + Activity.idle.defaultSheet)
            ?? SheetDef.catalog[0]
    }
    func setSheet(_ file: String, for a: Activity) {
        var map: [String: String] = decode(animSheetsRaw) ?? [:]
        map[key(a)] = file
        animSheetsRaw = encode(map); objectWillChange.send()
    }
    func fps(for a: Activity) -> Double {
        let map: [String: Double] = decode(animFpsRaw) ?? [:]
        return map[key(a)] ?? a.defaultFps
    }
    func setFps(_ v: Double, for a: Activity) {
        var map: [String: Double] = decode(animFpsRaw) ?? [:]
        map[key(a)] = v
        animFpsRaw = encode(map); objectWillChange.send()
    }

    // Stringa vuota = mai configurato -> default.
    var infoFields: Set<InfoField> {
        get {
            guard !infoFieldsRaw.isEmpty else { return InfoField.defaults }
            return Set(infoFieldsRaw.split(separator: ",").compactMap { InfoField(rawValue: String($0)) })
        }
        set { infoFieldsRaw = newValue.map(\.rawValue).sorted().joined(separator: ",") + ","; objectWillChange.send() }
    }

    func resetAnimations() { animSheetsRaw = "{}"; animFpsRaw = "{}"; objectWillChange.send() }

    private func decode<T: Decodable>(_ s: String) -> T? { try? JSONDecoder().decode(T.self, from: Data(s.utf8)) }
    private func encode<T: Encodable>(_ v: T) -> String {
        (try? JSONEncoder().encode(v)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }
}

struct TamagotchiView: View {
    @ObservedObject var watcher: StateWatcher
    @ObservedObject var settings: Settings
    @ObservedObject var rateCache: RateCacheWatcher
    @State private var hovering = false

    private var st: TamagotchiState { watcher.current }
    private var sc: CGFloat { settings.sizePreset.scale }
    private var fields: Set<InfoField> { settings.infoFields }
    private var statFields: [InfoField] { InfoField.allCases.filter { fields.contains($0) && $0.isStat } }

    var body: some View {
        VStack(spacing: 4 * sc) {
            // Rivaluta ogni 30s per passare da idle a "dorme".
            TimelineView(.periodic(from: .now, by: 30)) { tl in
                let a = Activity.from(st, now: tl.date, sleepAfter: settings.sleepMinutes * 60)
                SpriteSheetView(sheet: settings.sheet(for: a), fps: settings.fps(for: a))
            }
            .frame(width: 96 * sc, height: 96 * sc)

            if settings.showStats && !statFields.isEmpty && (hovering || settings.statsAlways) {
                StatsRows(fields: statFields, st: st, cache: rateCache.cache, scale: sc)
                    .transition(.opacity)
            } else if fields.contains(.caption) {
                Text(caption)
                    .font(.system(size: 10 * sc, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8 * sc)
        .frame(width: 120 * sc, height: 150 * sc)
        .background(background)
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { hovering = h } }
    }

    @ViewBuilder private var background: some View {
        let col = settings.bgColor.color(st.state)
        if settings.bgTransparent {
            // Alpha quasi zero: invisibile, ma la finestra resta cliccabile e trascinabile.
            RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.001))
        } else {
            RoundedRectangle(cornerRadius: 18)
                .fill(col)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(col.opacity(0.6)))
        }
    }

    private var caption: String {
        switch st.state {
        case .idle: return "in attesa"
        case .working: return (st.tool.isEmpty || !fields.contains(.tool)) ? "al lavoro…" : st.tool
        case .waiting: return "tocca a te ✋"
        case .done: return "fatto! 🎉"
        case .error: return "ops…"
        }
    }
}

// Righe statistiche scelte in dashboard. Max 3: il panel non ha spazio per altre.
struct StatsRows: View {
    let fields: [InfoField]
    let st: TamagotchiState
    let cache: RateCache
    var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 2) {
            ForEach(fields.prefix(3)) { f in row(f) }
        }
        .font(.system(size: 9 * scale, weight: .regular, design: .monospaced))
        .foregroundStyle(.secondary)
    }

    @ViewBuilder private func row(_ f: InfoField) -> some View {
        switch f {
        case .ctxTokens: line("ctx", compact(st.tokensInput))
        case .outTokens: line("out", compact(st.tokensOutput))
        case .toolCalls: line("tool", "\(st.toolCalls)")
        case .limit5h:   limitLine("5h", cache.r5, cache.r5ResetsAt, "HH:mm")
        case .limit7d:   limitLine("7d", cache.r7, cache.r7ResetsAt, "dd/MM")
        case .ctxPct:    line("ctx", "\(cache.contextPct)%")
        case .model:     line("mod", cache.model.isEmpty ? "—" : cache.model)
        case .caption, .tool: EmptyView()
        }
    }

    // Reset già passato = dato stantio (statusline non aggiorna la cache): mostra "—".
    private func limitLine(_ label: String, _ pct: Int, _ resetsAt: TimeInterval, _ format: String) -> some View {
        let stale = resetsAt > 0 && resetsAt < Date().timeIntervalSince1970
        return line(label, stale ? "—" : "\(pct)", reset: stale ? "" : resetLabel(resetsAt, format))
    }

    private func line(_ label: String, _ value: String, reset: String = "") -> some View {
        HStack(spacing: 4) {
            Text(label).frame(width: 22 * scale, alignment: .leading)
            Text(value).lineLimit(1)
            Spacer(minLength: 0)
            if !reset.isEmpty { Text(reset).foregroundStyle(.tertiary) }
        }
    }

    private func compact(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    private func resetLabel(_ ts: TimeInterval, _ format: String) -> String {
        guard ts > 0 else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = format
        return "→" + fmt.string(from: Date(timeIntervalSince1970: ts))
    }
}
