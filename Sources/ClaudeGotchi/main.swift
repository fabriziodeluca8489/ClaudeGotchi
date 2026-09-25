import AppKit
import SwiftUI
import Combine

// Pannello floating: sopra ogni finestra, su tutti gli Space e monitor, trascinabile.
final class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
    }
    // Necessario con .nonactivating per ricevere il menu contestuale/hover.
    override var canBecomeKey: Bool { true }
}

final class MenuHostingView<Content: View>: NSHostingView<Content> {
    override func rightMouseDown(with event: NSEvent) {
        if let menu = self.menu {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = Settings()
    let watcher = StateWatcher(path: HookInstaller.bridgePath)
    let rateCache = RateCacheWatcher()
    private var panel: FloatingPanel!
    private var hosting: MenuHostingView<TamagotchiView>!
    private var dashboard: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = TamagotchiView(watcher: watcher, settings: settings, rateCache: rateCache)
        panel = FloatingPanel()
        hosting = MenuHostingView(rootView: root)
        hosting.menu = buildMenu()               // menu contestuale (click destro)
        panel.contentView = hosting

        // Posizione iniziale: angolo alto-destra dello schermo principale.
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            let sc = settings.sizePreset.scale
            let w = 120 * sc, h = 150 * sc
            panel.setFrame(NSRect(x: f.maxX - w - 20, y: f.maxY - h - 10, width: w, height: h), display: false)
        }
        panel.orderFrontRegardless()

        // Ridimensiona il panel quando cambia il preset.
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.resizePanel()
                    // Ricostruisce il menu: le spunte restano allineate alle modifiche fatte in dashboard.
                    self?.hosting.menu = self?.buildMenu()
                }
            }
            .store(in: &cancellables)

        // Reazioni ai cambi di stato: celebrazione "done" + badge dock.
        watcher.$doneTrigger
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.celebrate() }
            .store(in: &cancellables)

        watcher.$current
            .map(\.state)
            .removeDuplicates()
            .sink { st in if st != .done { NSApp.dockTile.badgeLabel = nil } }
            .store(in: &cancellables)
    }

    // MARK: - Resize panel al cambio dimensione

    private func resizePanel() {
        let sc = settings.sizePreset.scale
        let newW = 120 * sc, newH = 150 * sc
        // Ancora angolo in alto a destra del panel corrente.
        let maxX = panel.frame.maxX
        let maxY = panel.frame.maxY
        panel.setFrame(NSRect(x: maxX - newW, y: maxY - newH, width: newW, height: newH), display: true, animate: true)
    }

    // MARK: - Celebrazione task done: flash + suono + badge

    private func celebrate() {
        NSSound(named: "Glass")?.play()
        NSApp.dockTile.badgeLabel = "✓"
        flash(times: 3)
    }

    private func flash(times: Int) {
        guard times > 0 else { panel.alphaValue = 1; return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0.25
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.12
                self.panel.animator().alphaValue = 1
            }, completionHandler: { self.flash(times: times - 1) })
        })
    }

    // MARK: - Menu contestuale

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Dashboard…", action: #selector(openDashboard), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "☕ Dona con PayPal…", action: #selector(openDonate), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let skinItem = NSMenuItem(title: "Skin", action: nil, keyEquivalent: "")
        let skinSub = NSMenu()
        for s in Skin.allCases {
            let it = NSMenuItem(title: s.label, action: #selector(selectSkin(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = s.rawValue
            it.state = (settings.skin == s) ? .on : .off
            skinSub.addItem(it)
        }
        skinItem.submenu = skinSub
        menu.addItem(skinItem)

        let sizeItem = NSMenuItem(title: "Dimensione", action: nil, keyEquivalent: "")
        let sizeSub = NSMenu()
        for p in SizePreset.allCases {
            let it = NSMenuItem(title: p.label, action: #selector(selectSize(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = p.rawValue
            it.state = (settings.sizePreset == p) ? .on : .off
            sizeSub.addItem(it)
        }
        sizeItem.submenu = sizeSub
        menu.addItem(sizeItem)

        menu.addItem(.separator())

        let statsItem = NSMenuItem(title: "Mostra statistiche", action: #selector(toggleStats), keyEquivalent: "")
        statsItem.target = self
        statsItem.state = settings.showStats ? .on : .off
        menu.addItem(statsItem)

        let bgItem = NSMenuItem(title: "Sfondo", action: nil, keyEquivalent: "")
        let bgSub = NSMenu()
        let transpItem = NSMenuItem(title: "Trasparente", action: #selector(toggleBgTransparent), keyEquivalent: "")
        transpItem.target = self
        transpItem.state = settings.bgTransparent ? .on : .off
        bgSub.addItem(transpItem)
        bgSub.addItem(.separator())
        for c in BGColor.allCases {
            let it = NSMenuItem(title: c.label, action: #selector(selectBgColor(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = c.rawValue
            it.state = (settings.bgColor == c) ? .on : .off
            bgSub.addItem(it)
        }
        bgItem.submenu = bgSub
        menu.addItem(bgItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Installa hooks Claude Code", action: #selector(installHooks), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Rimuovi hooks Claude Code", action: #selector(uninstallHooks), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func openDonate() { NSWorkspace.shared.open(donateURL) }

    @objc private func openDashboard() {
        if dashboard == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 700),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
            w.title = "ClaudeGotchi — Dashboard"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: DashboardView(settings: settings, watcher: watcher))
            w.center()
            dashboard = w
        }
        NSApp.activate(ignoringOtherApps: true)
        dashboard?.makeKeyAndOrderFront(nil)
    }

    @objc private func selectSkin(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let s = Skin(rawValue: raw) else { return }
        settings.skin = s
        sender.menu?.items.forEach { $0.state = ($0.representedObject as? String == raw) ? .on : .off }
    }

    @objc private func selectSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let p = SizePreset(rawValue: raw) else { return }
        settings.sizePreset = p
        sender.menu?.items.forEach { $0.state = ($0.representedObject as? String == raw) ? .on : .off }
    }

    @objc private func toggleStats(_ sender: NSMenuItem) {
        settings.showStats.toggle()
        sender.state = settings.showStats ? .on : .off
    }

    @objc private func toggleBgTransparent(_ sender: NSMenuItem) {
        settings.bgTransparent.toggle()
        sender.state = settings.bgTransparent ? .on : .off
    }

    @objc private func selectBgColor(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let c = BGColor(rawValue: raw) else { return }
        settings.bgColor = c
        sender.menu?.items.forEach { $0.state = ($0.representedObject as? String == raw) ? .on : .off }
    }

    @objc private func installHooks() {
        do { try HookInstaller.install()
            alert("Hook installati", "Riavvia la sessione Claude Code per attivarli.")
        } catch { alert("Errore installazione", error.localizedDescription) }
    }

    @objc private func uninstallHooks() {
        do { try HookInstaller.uninstall(); alert("Hook rimossi", "settings.json ripristinato.") }
        catch { alert("Errore rimozione", error.localizedDescription) }
    }

    private func alert(_ title: String, _ msg: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = msg
        a.runModal()
    }
}

// Modalità CLI headless per install/rimozione hook (scriptabile e testabile).
switch CommandLine.arguments.dropFirst().first {
case "--install-hooks":
    do { try HookInstaller.install(); print("hooks installati in \(HookInstaller.hooksDir)"); exit(0) }
    catch { FileHandle.standardError.write(Data("errore: \(error)\n".utf8)); exit(1) }
case "--uninstall-hooks":
    do { try HookInstaller.uninstall(); print("hooks rimossi"); exit(0) }
    catch { FileHandle.standardError.write(Data("errore: \(error)\n".utf8)); exit(1) }
default:
    break
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)   // .regular per abilitare il badge nel dock
let delegate = AppDelegate()
app.delegate = delegate
app.run()
