import SwiftUI
import AppKit

// Attività mostrata dal personaggio: ricavata da stato hook + tool + inattività.
enum Activity: String, CaseIterable, Identifiable {
    case idle, sleeping, reading, writing, bash, working, waiting, done, error
    var id: String { rawValue }

    var label: String {
        switch self {
        case .idle:     return "In attesa"
        case .sleeping: return "Dorme (inattivo)"
        case .reading:  return "Legge (Read/Grep/Glob)"
        case .writing:  return "Scrive (Edit/Write)"
        case .bash:     return "Terminale (Bash)"
        case .working:  return "Al lavoro (altri tool)"
        case .waiting:  return "Attende permesso"
        case .done:     return "Finito"
        case .error:    return "Errore"
        }
    }

    // Nome base dello sheet (file "<nome>_<righe>x<colonne>.png" in Resources/).
    var defaultSheet: String {
        switch self {
        case .idle:     return "idle"
        case .sleeping: return "sleep"
        case .reading:  return "reading"
        case .writing:  return "writing_code"
        case .bash:     return "terminal"
        case .working:  return "working"
        case .waiting:  return "waiting_permission"
        case .done:     return "done"
        case .error:    return "error"
        }
    }

    // Tutte le strisce sono pensate per 8 fps (vedi animations.json).
    var defaultFps: Double { 8 }

    private static let iso = ISO8601DateFormatter()

    static func from(_ st: TamagotchiState, now: Date, sleepAfter: TimeInterval) -> Activity {
        switch st.state {
        case .idle:
            // Il timestamp è l'ultima scrittura degli hook: idle da troppo -> dorme.
            if let t = iso.date(from: st.timestamp), now.timeIntervalSince(t) > sleepAfter { return .sleeping }
            return .idle
        case .working:
            switch st.tool {
            case "Read", "Grep", "Glob", "WebFetch", "WebSearch": return .reading
            case "Edit", "Write", "MultiEdit", "NotebookEdit": return .writing
            case "Bash": return .bash
            default: return .working
            }
        case .waiting: return .waiting
        case .done: return .done
        case .error: return .error
        }
    }
}

// Sprite sheet PNG in Resources/ chiamato "<nome>_<righe>x<colonne>.png" (es. idle_1x8.png):
// griglia letta dal nome, frame = dimensione immagine / griglia.
struct SheetDef: Identifiable, Hashable {
    let file: String
    let name: String
    let cols: Int
    let rows: Int
    var id: String { file }
    var label: String { name.replacingOccurrences(of: "_", with: " ").capitalized }

    // Tutti gli sheet presenti in Resources/ con nome valido, in ordine alfabetico.
    static let catalog: [SheetDef] = (Bundle.module.urls(forResourcesWithExtension: "png",
                                                          subdirectory: "Resources") ?? [])
        .compactMap { parse($0.deletingPathExtension().lastPathComponent) }
        .sorted { $0.name < $1.name }

    static func parse(_ file: String) -> SheetDef? {
        guard let m = file.wholeMatch(of: #/(.+)_(\d+)x(\d+)/#),
              let r = Int(m.2), let c = Int(m.3), r > 0, c > 0 else { return nil }
        return SheetDef(file: file, name: String(m.1), cols: c, rows: r)
    }

    // Accetta sia il nome file completo sia il nome base.
    static func named(_ key: String) -> SheetDef? { catalog.first { $0.file == key || $0.name == key } }
}

// Frame ritagliati una volta sola per sheet. Usato solo dal main thread (body SwiftUI).
enum SpriteCache {
    private static var frames: [String: [NSImage]] = [:]

    static func frames(_ s: SheetDef) -> [NSImage] {
        if let f = frames[s.file] { return f }
        var out: [NSImage] = []
        if let img = loadImage(s.file) {
            let fw = img.width / s.cols, fh = img.height / s.rows
            for r in 0..<s.rows {
                for c in 0..<s.cols {
                    let rect = CGRect(x: c * fw, y: r * fh, width: fw, height: fh)
                    if let cg = img.cropping(to: rect) {
                        out.append(NSImage(cgImage: cg, size: NSSize(width: fw, height: fh)))
                    }
                }
            }
        }
        frames[s.file] = out
        return out
    }

    private static func loadImage(_ name: String) -> CGImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png",
                                           subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let img = CGImage(pngDataProviderSource: provider,
                                decode: nil, shouldInterpolate: true,
                                intent: .defaultIntent)
        else { return nil }
        return img
    }
}

// Cicla i frame dello sheet alla velocità richiesta.
struct SpriteSheetView: View {
    let sheet: SheetDef
    let fps: Double

    var body: some View {
        let frames = SpriteCache.frames(sheet)
        if frames.isEmpty {
            Image(systemName: "questionmark").resizable().aspectRatio(contentMode: .fit)
        } else {
            TimelineView(.animation(minimumInterval: 1 / max(fps, 1))) { tl in
                let idx = Int(tl.date.timeIntervalSinceReferenceDate * fps) % frames.count
                Image(nsImage: frames[idx])
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}
