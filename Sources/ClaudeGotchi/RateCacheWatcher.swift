import Foundation
import Combine

struct RateCache: Codable, Equatable {
    var r5: Int = 0
    var r7: Int = 0
    var r5ResetsAt: TimeInterval = 0
    var r7ResetsAt: TimeInterval = 0
    var contextPct: Int = 0
    var model: String = ""

    enum CodingKeys: String, CodingKey {
        case r5, r7
        case r5ResetsAt = "r5_resets_at"
        case r7ResetsAt = "r7_resets_at"
        case contextPct = "context_pct"
        case model
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        r5 = (try? c.decode(Int.self, forKey: .r5)) ?? 0
        r7 = (try? c.decode(Int.self, forKey: .r7)) ?? 0
        // Il campo può essere stringa o numero.
        if let s = try? c.decode(String.self, forKey: .r5ResetsAt) {
            r5ResetsAt = TimeInterval(s) ?? 0
        } else {
            r5ResetsAt = (try? c.decode(TimeInterval.self, forKey: .r5ResetsAt)) ?? 0
        }
        if let s = try? c.decode(String.self, forKey: .r7ResetsAt) {
            r7ResetsAt = TimeInterval(s) ?? 0
        } else {
            r7ResetsAt = (try? c.decode(TimeInterval.self, forKey: .r7ResetsAt)) ?? 0
        }
        contextPct = (try? c.decode(Int.self, forKey: .contextPct)) ?? 0
        model = (try? c.decode(String.self, forKey: .model)) ?? ""
    }
}

final class RateCacheWatcher: ObservableObject {
    @Published private(set) var cache = RateCache()

    private let url: URL
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private let queue = DispatchQueue(label: "claudegotchi.ratecache")
    private var probeTimer: Timer?
    private static let probeInterval: TimeInterval = 600

    init(path: String = "~/.claude/rate-cache.json") {
        self.url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        reload()
        openWatch()
        probe()
        probeTimer = Timer.scheduledTimer(withTimeInterval: Self.probeInterval, repeats: true) { [weak self] _ in self?.probe() }
    }

    deinit { closeWatch() }

    private func openWatch() {
        fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            queue.asyncAfter(deadline: .now() + 2) { [weak self] in self?.openWatch() }
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete, .attrib],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = self.source?.data ?? []
            self.reload()
            if flags.contains(.rename) || flags.contains(.delete) {
                self.closeWatch()
                self.queue.asyncAfter(deadline: .now() + 0.1) { self.openWatch() }
            }
        }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 { close(fd); self?.fd = -1 }
        }
        source = src
        src.resume()
    }

    // Fallback senza statusline (es. estensione VS Code): un messaggio minimo in `claude -p` emette un
    // rate_limit_event con l'utilizzo 5h/7d. --setting-sources "" evita che partano gli hook del pet.
    // Parte solo se rate-cache.json è più vecchio di probeInterval. Costa un messaggio haiku.
    private func probe() {
        queue.async { [url] in
            let mtime = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
            guard Date().timeIntervalSince(mtime) >= Self.probeInterval else { return }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // Shell di login: un'app grafica non ha il PATH dove sta `claude`.
            p.arguments = ["-lc", "claude -p ok --model haiku --setting-sources '' --output-format stream-json --verbose 2>/dev/null"]
            p.currentDirectoryURL = FileManager.default.temporaryDirectory
            let pipe = Pipe()
            p.standardOutput = pipe
            guard (try? p.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard let out = String(data: data, encoding: .utf8),
                  let line = out.split(separator: "\n").first(where: { $0.contains("\"rate_limit_event\"") }),
                  let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let w = (obj["rate_limit_info"] as? [String: Any])?["unifiedWindows"] as? [String: Any] else { return }
            func win(_ k: String) -> (Int, String) {
                let d = w[k] as? [String: Any]
                let u = (d?["utilization"] as? Double) ?? 0 // frazione 0-1
                let r = (d?["resetsAt"] as? Double).map { String(Int($0)) } ?? ""
                return (Int((u * 100).rounded()), r)
            }
            var json = (try? JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]) ?? [:]
            let (r5, r5at) = win("five_hour"), (r7, r7at) = win("seven_day")
            json["r5"] = r5; json["r7"] = r7
            json["r5_resets_at"] = r5at; json["r7_resets_at"] = r7at
            json["ts"] = Int(Date().timeIntervalSince1970)
            if let out = try? JSONSerialization.data(withJSONObject: json) { try? out.write(to: url, options: .atomic) }
        }
    }

    private func closeWatch() { source?.cancel(); source = nil }

    private func reload() {
        let next: RateCache
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(RateCache.self, from: data) {
            next = decoded
        } else {
            next = RateCache()
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.cache != next else { return }
            self.cache = next
        }
    }
}
