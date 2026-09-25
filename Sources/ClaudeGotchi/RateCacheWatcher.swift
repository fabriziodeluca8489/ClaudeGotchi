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

    init(path: String = "~/.claude/rate-cache.json") {
        self.url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        reload()
        openWatch()
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
