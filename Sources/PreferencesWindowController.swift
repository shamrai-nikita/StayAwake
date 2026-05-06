import Cocoa

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private let sleepManager: SleepManager
    private let loginItemManager: LoginItemManager
    weak var statusBarManager: StatusBarManager?

    private var statusDot: NSImageView!
    private var statusLabel: NSTextField!
    private var toggleButton: NSButton!
    private var durationPopup: NSPopUpButton!
    private var activateForButton: NSButton!
    private var timerStatusLabel: NSTextField!
    private var cancelTimerButton: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var activateOnStartCheckbox: NSButton!
    private var requireTouchIDCheckbox: NSButton!

    private static let windowWidth: CGFloat = 460
    private static let windowHeight: CGFloat = 600

    init(sleepManager: SleepManager,
         loginItemManager: LoginItemManager,
         statusBarManager: StatusBarManager?) {
        self.sleepManager = sleepManager
        self.loginItemManager = loginItemManager
        self.statusBarManager = statusBarManager

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0,
                                width: Self.windowWidth,
                                height: Self.windowHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "StayAwake"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
        buildUI()
        refreshState()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStateChange),
            name: .sleepStateChanged,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func buildUI() {
        guard let v = window?.contentView else { return }
        let margin: CGFloat = 24
        let contentWidth: CGFloat = Self.windowWidth - margin * 2

        // ── Status row ────────────────────────────────────────────────
        let statusY: CGFloat = 562
        statusDot = NSImageView(frame: NSRect(x: margin, y: statusY, width: 14, height: 14))
        statusDot.imageScaling = .scaleProportionallyUpOrDown
        statusDot.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
        v.addSubview(statusDot)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusLabel.frame = NSRect(x: margin + 22, y: statusY - 4, width: contentWidth - 22, height: 22)
        v.addSubview(statusLabel)

        // ── Primary toggle button ─────────────────────────────────────
        let buttonWidth: CGFloat = 200
        toggleButton = NSButton(title: "Activate", target: self, action: #selector(didTapToggle))
        toggleButton.bezelStyle = .rounded
        toggleButton.keyEquivalent = "\r"
        toggleButton.frame = NSRect(x: (Self.windowWidth - buttonWidth) / 2,
                                    y: 504, width: buttonWidth, height: 32)
        v.addSubview(toggleButton)

        let tip = NSTextField(labelWithString: "Or click the menu bar icon to toggle anytime.")
        tip.font = .systemFont(ofSize: 11)
        tip.textColor = .secondaryLabelColor
        tip.alignment = .center
        tip.frame = NSRect(x: margin, y: 480, width: contentWidth, height: 16)
        v.addSubview(tip)

        // ── Lid-closed banner ─────────────────────────────────────────
        let bannerHeight: CGFloat = 56
        let bannerY: CGFloat = 408
        let banner = NSView(frame: NSRect(x: margin, y: bannerY, width: contentWidth, height: bannerHeight))
        banner.wantsLayer = true
        banner.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.12).cgColor
        banner.layer?.cornerRadius = 8
        v.addSubview(banner)

        let bannerIcon = NSImageView(frame: NSRect(x: 12, y: bannerHeight - 30, width: 18, height: 18))
        bannerIcon.image = NSImage(systemSymbolName: "info.circle.fill", accessibilityDescription: nil)
        bannerIcon.contentTintColor = .systemBlue
        bannerIcon.symbolConfiguration = .init(pointSize: 14, weight: .semibold)
        banner.addSubview(bannerIcon)

        let bannerText = NSTextField(wrappingLabelWithString: "While enabled, your Mac will not sleep with the lid closed \u{2014} and the display stays on too. Make sure it's somewhere ventilated.")
        bannerText.font = .systemFont(ofSize: 11)
        bannerText.textColor = .labelColor
        bannerText.maximumNumberOfLines = 3
        bannerText.frame = NSRect(x: 38, y: 6, width: contentWidth - 50, height: bannerHeight - 12)
        banner.addSubview(bannerText)

        // ── TIMER section ─────────────────────────────────────────────
        let timerSep = NSBox()
        timerSep.boxType = .separator
        timerSep.frame = NSRect(x: margin, y: 388, width: contentWidth, height: 1)
        v.addSubview(timerSep)

        let timerHeader = NSTextField(labelWithString: "TIMER")
        timerHeader.font = .systemFont(ofSize: 11, weight: .semibold)
        timerHeader.textColor = .secondaryLabelColor
        timerHeader.frame = NSRect(x: margin, y: 360, width: contentWidth, height: 14)
        v.addSubview(timerHeader)

        let durationLabel = NSTextField(labelWithString: "Activate for:")
        durationLabel.font = .systemFont(ofSize: 12)
        durationLabel.frame = NSRect(x: margin, y: 326, width: 90, height: 22)
        v.addSubview(durationLabel)

        durationPopup = NSPopUpButton(frame: NSRect(x: margin + 96, y: 322, width: 160, height: 26))
        for preset in DurationPreset.presets {
            durationPopup.addItem(withTitle: preset.title)
            durationPopup.lastItem?.representedObject = preset.seconds
        }
        durationPopup.menu?.addItem(.separator())
        let indefinite = NSMenuItem(title: "Indefinitely", action: nil, keyEquivalent: "")
        indefinite.representedObject = NSNull()
        durationPopup.menu?.addItem(indefinite)
        // Default selection: 30 minutes
        durationPopup.selectItem(at: 2)
        v.addSubview(durationPopup)

        activateForButton = NSButton(title: "Activate",
                                     target: self,
                                     action: #selector(didTapActivateFor))
        activateForButton.bezelStyle = .rounded
        activateForButton.frame = NSRect(x: margin + 96 + 168, y: 322, width: 90, height: 26)
        v.addSubview(activateForButton)

        timerStatusLabel = NSTextField(labelWithString: "")
        timerStatusLabel.font = .systemFont(ofSize: 11)
        timerStatusLabel.textColor = .secondaryLabelColor
        timerStatusLabel.frame = NSRect(x: margin, y: 294, width: contentWidth - 110, height: 18)
        v.addSubview(timerStatusLabel)

        cancelTimerButton = NSButton(title: "Cancel timer",
                                     target: self,
                                     action: #selector(didCancelTimer))
        cancelTimerButton.bezelStyle = .recessed
        cancelTimerButton.controlSize = .small
        cancelTimerButton.frame = NSRect(x: Self.windowWidth - margin - 100,
                                          y: 292, width: 100, height: 22)
        cancelTimerButton.isHidden = true
        v.addSubview(cancelTimerButton)

        // ── STARTUP section ───────────────────────────────────────────
        let startupSep = NSBox()
        startupSep.boxType = .separator
        startupSep.frame = NSRect(x: margin, y: 270, width: contentWidth, height: 1)
        v.addSubview(startupSep)

        let startupHeader = NSTextField(labelWithString: "STARTUP")
        startupHeader.font = .systemFont(ofSize: 11, weight: .semibold)
        startupHeader.textColor = .secondaryLabelColor
        startupHeader.frame = NSRect(x: margin, y: 242, width: contentWidth, height: 14)
        v.addSubview(startupHeader)

        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login",
                                         target: self,
                                         action: #selector(didToggleLaunchAtLogin))
        launchAtLoginCheckbox.frame = NSRect(x: margin, y: 212, width: contentWidth, height: 22)
        v.addSubview(launchAtLoginCheckbox)

        activateOnStartCheckbox = NSButton(checkboxWithTitle: "Prevent sleep on launch",
                                            target: self,
                                            action: #selector(didToggleActivateOnStart))
        activateOnStartCheckbox.frame = NSRect(x: margin, y: 184, width: contentWidth, height: 22)
        v.addSubview(activateOnStartCheckbox)

        // ── SECURITY section ──────────────────────────────────────────
        let securitySep = NSBox()
        securitySep.boxType = .separator
        securitySep.frame = NSRect(x: margin, y: 162, width: contentWidth, height: 1)
        v.addSubview(securitySep)

        let securityHeader = NSTextField(labelWithString: "SECURITY")
        securityHeader.font = .systemFont(ofSize: 11, weight: .semibold)
        securityHeader.textColor = .secondaryLabelColor
        securityHeader.frame = NSRect(x: margin, y: 134, width: contentWidth, height: 14)
        v.addSubview(securityHeader)

        requireTouchIDCheckbox = NSButton(checkboxWithTitle: "Require Touch ID to toggle",
                                          target: self,
                                          action: #selector(didToggleRequireTouchID))
        requireTouchIDCheckbox.frame = NSRect(x: margin, y: 104, width: contentWidth, height: 22)
        v.addSubview(requireTouchIDCheckbox)

        let securityHint = NSTextField(wrappingLabelWithString: "When off, toggling sleep prevention happens silently. Auto-disable on timer expiry never prompts.")
        securityHint.font = .systemFont(ofSize: 11)
        securityHint.textColor = .tertiaryLabelColor
        securityHint.maximumNumberOfLines = 2
        securityHint.frame = NSRect(x: margin + 22, y: 70, width: contentWidth - 22, height: 32)
        v.addSubview(securityHint)

        // ── Uninstall ─────────────────────────────────────────────────
        let uninstallWidth: CGFloat = 170
        let uninstallButton = NSButton(title: "Uninstall StayAwake\u{2026}",
                                       target: self,
                                       action: #selector(didTapUninstall))
        uninstallButton.bezelStyle = .recessed
        uninstallButton.controlSize = .small
        uninstallButton.contentTintColor = .systemRed
        uninstallButton.frame = NSRect(x: Self.windowWidth - margin - uninstallWidth,
                                        y: 22, width: uninstallWidth, height: 22)
        v.addSubview(uninstallButton)
    }

    func refreshState() {
        launchAtLoginCheckbox.state = loginItemManager.isEnabled ? .on : .off
        activateOnStartCheckbox.state = UserDefaults.standard.bool(forKey: "activateOnStart") ? .on : .off
        requireTouchIDCheckbox.state = UserDefaults.standard.bool(forKey: SleepManager.requireTouchIDKey) ? .on : .off
        applyStatus(active: sleepManager.isPreventingSleep)
    }

    private func applyStatus(active: Bool) {
        toggleButton.title = active ? "Disable" : "Activate"
        statusLabel.stringValue = active ? "Sleep prevented" : "Sleep allowed"
        statusDot.contentTintColor = active ? .systemGreen : .tertiaryLabelColor

        if let expiresAt = sleepManager.expiresAt {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            timerStatusLabel.stringValue = "Active until \(formatter.string(from: expiresAt))"
            cancelTimerButton.isHidden = false
        } else {
            timerStatusLabel.stringValue = active ? "Active indefinitely." : ""
            cancelTimerButton.isHidden = true
        }
    }

    @objc private func handleStateChange() {
        DispatchQueue.main.async { [weak self] in
            self?.applyStatus(active: self?.sleepManager.isPreventingSleep ?? false)
        }
    }

    @objc private func didToggleLaunchAtLogin() {
        loginItemManager.setEnabled(launchAtLoginCheckbox.state == .on)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshState()
        }
    }

    @objc private func didToggleActivateOnStart() {
        UserDefaults.standard.set(activateOnStartCheckbox.state == .on, forKey: "activateOnStart")
    }

    @objc private func didToggleRequireTouchID() {
        UserDefaults.standard.set(requireTouchIDCheckbox.state == .on, forKey: SleepManager.requireTouchIDKey)
    }

    @objc private func didTapToggle() {
        sleepManager.toggle { [weak self] nowActive in
            self?.statusBarManager?.updateIcon(active: nowActive)
            self?.applyStatus(active: nowActive)
        }
    }

    @objc private func didTapActivateFor() {
        guard let item = durationPopup.selectedItem else { return }
        if let seconds = item.representedObject as? TimeInterval {
            sleepManager.enableForDuration(seconds) { [weak self] active in
                self?.statusBarManager?.updateIcon(active: active)
                self?.applyStatus(active: active)
            }
        } else {
            // Indefinite
            sleepManager.enable { [weak self] active in
                self?.statusBarManager?.updateIcon(active: active)
                self?.applyStatus(active: active)
            }
        }
    }

    @objc private func didCancelTimer() {
        sleepManager.cancelTimer()
        applyStatus(active: sleepManager.isPreventingSleep)
    }

    @objc private func didTapUninstall() {
        let appPath = Bundle.main.bundlePath
        let alert = NSAlert()
        alert.messageText = "Uninstall StayAwake?"
        alert.informativeText = """
        This will:

        • Re-enable system sleep (pmset disablesleep 0)
        • Remove the Touch ID helper (/etc/sudoers.d/stayawake)
        • Remove the app: \(appPath)
        • Disable launch at login
        • Clear all StayAwake preferences

        You'll be asked for your admin password once. The app will quit immediately afterward.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        loginItemManager.setEnabled(false)

        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        let escapedPath = appPath.replacingOccurrences(of: "'", with: "'\\''")
        let shellCmd = "/usr/bin/pmset -a disablesleep 0; /bin/rm -f /etc/sudoers.d/stayawake; /bin/rm -rf '\(escapedPath)'"
        let escapedShell = shellCmd
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScriptSource = """
        do shell script "\(escapedShell)" with prompt "Uninstall StayAwake" with administrator privileges
        """
        var err: NSDictionary?
        NSAppleScript(source: appleScriptSource)?.executeAndReturnError(&err)

        NSApp.terminate(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
