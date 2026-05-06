import Cocoa

final class StatusBarManager {
    private let statusItem: NSStatusItem
    private let sleepManager: SleepManager
    private let onPreferences: () -> Void
    private let onQuit: () -> Void

    init(sleepManager: SleepManager,
         onPreferences: @escaping () -> Void,
         onQuit: @escaping () -> Void) {
        self.sleepManager = sleepManager
        self.onPreferences = onPreferences
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setupButton()
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.image = iconImage(active: false)
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
    }

    private func iconImage(active: Bool) -> NSImage? {
        let name = active ? "cup.and.saucer.fill" : "cup.and.saucer"
        let img = NSImage(systemSymbolName: name,
                          accessibilityDescription: active ? "Sleep prevented" : "Sleep allowed")
        img?.isTemplate = true
        return img
    }

    func updateIcon(active: Bool) {
        statusItem.button?.image = iconImage(active: active)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            let nowActive = sleepManager.toggle()
            updateIcon(active: nowActive)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let prefsItem = NSMenuItem(title: "Preferences\u{2026}",
                                   action: #selector(openPreferences),
                                   keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit StayAwake",
                                  action: #selector(quitApp),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPreferences() { onPreferences() }
    @objc private func quitApp() { onQuit() }
}
