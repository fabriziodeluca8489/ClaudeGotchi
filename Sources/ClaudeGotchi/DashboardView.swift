import SwiftUI

// Link donazioni PayPal (usato da menu e dashboard).
let donateURL = URL(string: "https://paypal.me/FabrizioDeLuca89")!

// Dashboard a 3 colonne: Attività | Anteprima live | Skin e impostazioni.
struct DashboardView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var watcher: StateWatcher
    @State private var selected: Activity = .idle

    var body: some View {
        VStack(spacing: 16) {
            header
            HStack(alignment: .top, spacing: 16) {
                activitiesColumn.frame(width: 280)
                previewColumn.frame(maxWidth: .infinity)
                settingsColumn.frame(width: 320)
            }
        }
        .padding(20)
        .frame(minWidth: 1000, minHeight: 680)
        .background(
            LinearGradient(colors: [Color(red: 0.24, green: 0.15, blue: 0.30),
                                    Color(red: 0.07, green: 0.06, blue: 0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var connected: Bool {
        // Collegato = il bridge file ha uno stato scritto dagli hook.
        !watcher.current.timestamp.isEmpty
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ClaudeGotchi").font(.system(size: 26, weight: .heavy, design: .rounded))
                Text("FLOATING COMPANION PER CLAUDE CODE")
                    .font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.secondary)
            }
            Spacer()
            Link(destination: donateURL) { pill("☕ Dona con PayPal") }.buttonStyle(.plain)
            pill(connected ? "Claude Code collegato" : "In attesa di Claude Code",
                 dot: connected ? .green : .gray)
            pill(ProcessInfo.processInfo.operatingSystemVersionString.replacingOccurrences(of: "Version ", with: "macOS "))
        }
    }

    // MARK: - Colonna attività

    private var activitiesColumn: some View {
        panel("ATTIVITÀ", badge: "\(Activity.allCases.count)") {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Activity.allCases) { a in activityCard(a) }
                }
            }
        }
    }

    private func activityCard(_ a: Activity) -> some View {
        let on = a == selected
        return Button { selected = a } label: {
            HStack(spacing: 10) {
                SpriteSheetView(sheet: settings.sheet(for: a), fps: settings.fps(for: a))
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(a.label).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text("\(Int(settings.fps(for: a))) fps · \(settings.sheet(for: a).label)")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(on ? 0.14 : 0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(on ? Color.accentColor : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Anteprima

    private var previewColumn: some View {
        let st = watcher.current
        return VStack(spacing: 12) {
            panel("ANTEPRIMA · \(selected.label.uppercased())") {
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(settings.bgColor.color(st.state).opacity(0.35))
                        SpriteSheetView(sheet: settings.sheet(for: selected), fps: settings.fps(for: selected))
                            .padding(24)
                        VStack {
                            Spacer()
                            pill(settings.skin.label, dot: cgTint(st.state)).padding(10)
                        }
                    }
                    .frame(height: 300)

                    HStack {
                        Picker("Animazione", selection: Binding(
                            get: { settings.sheet(for: selected).file },
                            set: { settings.setSheet($0, for: selected) }
                        )) {
                            ForEach(SheetDef.catalog) { s in Text(s.label).tag(s.file) }
                        }
                        Text("FPS").foregroundStyle(.secondary)
                        Slider(value: Binding(get: { settings.fps(for: selected) },
                                              set: { settings.setFps($0.rounded(), for: selected) }),
                               in: 1...15).frame(width: 140)
                        Text("\(Int(settings.fps(for: selected)))").monospacedDigit().frame(width: 22)
                    }
                    Text("Trascina · Passa il mouse per le stats · Click destro per il menu")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            panel("LIVE") {
                HStack(spacing: 0) {
                    stat("Stato", st.state.rawValue.capitalized, cgTint(st.state))
                    stat("Tool", st.tool.isEmpty ? "—" : st.tool)
                    stat("Token in", "\(st.tokensInput)")
                    stat("Token out", "\(st.tokensOutput)")
                    stat("Tool call", "\(st.toolCalls)")
                }
                if !st.taskSummary.isEmpty {
                    Text(st.taskSummary).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String, _ tint: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundStyle(tint).lineLimit(1)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Skin e impostazioni

    private var settingsColumn: some View {
        panel("SKIN", badge: "\(Skin.allCases.count)") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Skin.allCases) { skinCard($0) }

                    group("Aspetto") {
                        Picker("Dimensione", selection: binding(\.sizePreset)) {
                            ForEach(SizePreset.allCases) { Text($0.label).tag($0) }
                        }
                        Picker("Sfondo", selection: binding(\.bgColor)) {
                            ForEach(BGColor.allCases) { Text($0.label).tag($0) }
                        }
                        Toggle("Sfondo trasparente", isOn: binding(\.bgTransparent))
                    }
                    group("Info sotto il personaggio") {
                        ForEach(InfoField.allCases) { f in
                            Toggle(f.label, isOn: Binding(
                                get: { settings.infoFields.contains(f) },
                                set: { on in
                                    var s = settings.infoFields
                                    if on { s.insert(f) } else { s.remove(f) }
                                    settings.infoFields = s
                                }
                            ))
                        }
                        Toggle("Mostra statistiche", isOn: binding(\.showStats))
                        Toggle("Sempre visibili", isOn: binding(\.statsAlways))
                    }
                    group("Sonno") {
                        Stepper("Dorme dopo \(Int(settings.sleepMinutes)) min",
                                value: binding(\.sleepMinutes), in: 1...120)
                    }
                    Button("Ripristina animazioni predefinite") { settings.resetAnimations() }
                }
            }
        }
    }

    private func skinCard(_ s: Skin) -> some View {
        let on = s == settings.skin
        let idle = SheetDef.named(s.spritePrefix + Activity.idle.defaultSheet)
        return Button { settings.skin = s } label: {
            HStack(spacing: 10) {
                Group {
                    if let idle { SpriteSheetView(sheet: idle, fps: 8) } else { Color.clear }
                }
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08)))
                Text(s.label).font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Color.accentColor : .secondary)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(on ? 0.14 : 0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(on ? Color.accentColor : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Componenti

    private func panel<C: View>(_ title: String, badge: String? = nil,
                                @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.caption.weight(.heavy)).tracking(1.2)
                Spacer()
                if let badge { pill(badge) }
            }
            content()
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.28)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08)))
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func pill(_ text: String, dot: Color? = nil) -> some View {
        HStack(spacing: 6) {
            if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.10)))
    }

    // Binding su proprietà di Settings (le computed inviano già objectWillChange).
    private func binding<T>(_ kp: ReferenceWritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { settings[keyPath: kp] }, set: { settings[keyPath: kp] = $0 })
    }
}
