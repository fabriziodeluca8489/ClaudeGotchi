import Foundation
import Combine

// Stato del personaggio, mappa 1:1 il bridge file scritto dagli hook.
enum CGState: String, Codable {
    case idle, working, waiting, done, error
}

struct TamagotchiState: Codable, Equatable {
    var state: CGState = .idle
    var tool: String = ""
    var taskSummary: String = ""
    var tokensInput: Int = 0
    var tokensOutput: Int = 0
    var toolCalls: Int = 0
    var sessionId: String = ""
    var timestamp: String = ""

    enum CodingKeys: String, CodingKey {
        case state, tool
        case taskSummary = "task_summary"
        case tokensInput = "tokens_input"
        case tokensOutput = "tokens_output"
        case toolCalls = "tool_calls"
        case sessionId = "session_id"
        case timestamp
    }

    // Decoder tollerante: campi mancanti -> default, stato ignoto -> idle.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = (try? c.decode(CGState.self, forKey: .state)) ?? .idle
        tool = (try? c.decode(String.self, forKey: .tool)) ?? ""
        taskSummary = (try? c.decode(String.self, forKey: .taskSummary)) ?? ""
        tokensInput = (try? c.decode(Int.self, forKey: .tokensInput)) ?? 0
        tokensOutput = (try? c.decode(Int.self, forKey: .tokensOutput)) ?? 0
        toolCalls = (try? c.decode(Int.self, forKey: .toolCalls)) ?? 0
        sessionId = (try? c.decode(String.self, forKey: .sessionId)) ?? ""
        timestamp = (try? c.decode(String.self, forKey: .timestamp)) ?? ""
    }

    init() {}
}

// Osserva il bridge file via DispatchSource (FSEvents) e pubblica lo stato.
final class StateWatcher: ObservableObject {
    @Published private(set) var current = TamagotchiState()
    // Incrementato a ogni transizione verso "done": la view lo usa per la celebrazione.
    @Published private(set) var doneTrigger = 0

    private let url: URL
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private let queue = DispatchQueue(label: "claudegotchi.watcher")

    init(path: String) {
        self.url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        reload()
        openWatch()
    }

    deinit { closeWatch() }

    private func openWatch() {
        // Se il file non esiste ancora, riprova a breve.
        fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.openWatch() }
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
            // mv atomico degli hook -> rename/delete: riapri l'fd sul nuovo inode.
            if flags.contains(.rename) || flags.contains(.delete) {
                self.closeWatch()
                self.queue.asyncAfter(deadline: .now() + 0.05) { self.openWatch() }
            }
        }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 { close(fd); self?.fd = -1 }
        }
        source = src
        src.resume()
    }

    private func closeWatch() {
        source?.cancel()
        source = nil
    }

    private func reload() {
        let next: TamagotchiState
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(TamagotchiState.self, from: data) {
            next = decoded
        } else {
            next = TamagotchiState()
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let wasDone = self.current.state == .done
            if self.current != next {
                self.current = next
                if next.state == .done && !wasDone {
                    self.doneTrigger &+= 1
                }
            }
        }
    }
}
