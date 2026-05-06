import Cocoa

struct DurationPreset {
    let title: String
    let seconds: TimeInterval

    static let presets: [DurationPreset] = [
        .init(title: "5 minutes",  seconds: 5 * 60),
        .init(title: "15 minutes", seconds: 15 * 60),
        .init(title: "30 minutes", seconds: 30 * 60),
        .init(title: "1 hour",     seconds: 60 * 60),
        .init(title: "2 hours",    seconds: 2 * 60 * 60),
        .init(title: "5 hours",    seconds: 5 * 60 * 60),
    ]
}

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStateChange),
            name: .sleepStateChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.image = iconImage(active: false)
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
    }

    private func iconImage(active: Bool) -> NSImage? {
        let img = Icons.burningEye(active: active)
        img.accessibilityDescription = active ? "Sleep prevented" : "Sleep allowed"
        return img
    }

    func updateIcon(active: Bool) {
        statusItem.button?.image = iconImage(active: active)
        updateTooltip()
    }

    private func updateTooltip() {
        guard let button = statusItem.button else { return }
        if let expiresAt = sleepManager.expiresAt {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            button.toolTip = "Active until \(formatter.string(from: expiresAt))"
        } else if sleepManager.isPreventingSleep {
            button.toolTip = "Sleep prevented"
        } else {
            button.toolTip = "Sleep allowed"
        }
    }

    @objc private func handleStateChange() {
        updateIcon(active: sleepManager.isPreventingSleep)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            sleepManager.toggle { [weak self] nowActive in
                self?.updateIcon(active: nowActive)
            }
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let active = sleepManager.isPreventingSleep

        // Toggle item — mirrors current behaviour for indefinite activation.
        let toggleTitle = active ? "Disable" : "Activate"
        let toggleItem = NSMenuItem(title: toggleTitle,
                                    action: #selector(didTapToggle),
                                    keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        // "Activate for ▸" submenu (always available — switches to a new
        // duration even when already active).
        let activateForItem = NSMenuItem(title: "Activate for", action: nil, keyEquivalent: "")
        let activateForMenu = NSMenu()
        for preset in DurationPreset.presets {
            let item = NSMenuItem(title: preset.title,
                                  action: #selector(didPickDuration(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = preset.seconds
            activateForMenu.addItem(item)
        }
        activateForMenu.addItem(.separator())
        let indefiniteItem = NSMenuItem(title: "Indefinitely",
                                        action: #selector(didPickIndefinite),
                                        keyEquivalent: "")
        indefiniteItem.target = self
        activateForMenu.addItem(indefiniteItem)
        activateForItem.submenu = activateForMenu
        menu.addItem(activateForItem)

        // Active-until row + cancel timer (only when a timer is running).
        if let expiresAt = sleepManager.expiresAt {
            menu.addItem(.separator())
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let info = NSMenuItem(title: "Active until \(formatter.string(from: expiresAt))",
                                  action: nil,
                                  keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)

            let cancel = NSMenuItem(title: "Cancel timer",
                                    action: #selector(didCancelTimer),
                                    keyEquivalent: "")
            cancel.target = self
            menu.addItem(cancel)
        }

        menu.addItem(.separator())
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

    @objc private func didTapToggle() {
        sleepManager.toggle { [weak self] nowActive in
            self?.updateIcon(active: nowActive)
        }
    }

    @objc private func didPickDuration(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        sleepManager.enableForDuration(seconds) { [weak self] active in
            self?.updateIcon(active: active)
        }
    }

    @objc private func didPickIndefinite() {
        sleepManager.enable { [weak self] active in
            self?.updateIcon(active: active)
        }
    }

    @objc private func didCancelTimer() {
        sleepManager.cancelTimer()
    }

    @objc private func openPreferences() { onPreferences() }
    @objc private func quitApp() { onQuit() }
}
