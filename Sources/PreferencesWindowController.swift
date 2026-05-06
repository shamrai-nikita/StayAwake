import Cocoa

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private let sleepManager: SleepManager
    private let loginItemManager: LoginItemManager
    weak var statusBarManager: StatusBarManager?

    private var statusDot: NSImageView!
    private var statusLabel: NSTextField!
    private var toggleButton: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var activateOnStartCheckbox: NSButton!

    init(sleepManager: SleepManager,
         loginItemManager: LoginItemManager,
         statusBarManager: StatusBarManager?) {
        self.sleepManager = sleepManager
        self.loginItemManager = loginItemManager
        self.statusBarManager = statusBarManager

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
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
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let v = window?.contentView else { return }
        let margin: CGFloat = 24
        let contentWidth: CGFloat = 420 - margin * 2

        // Status row — colored dot + state text
        statusDot = NSImageView(frame: NSRect(x: margin, y: 342, width: 14, height: 14))
        statusDot.imageScaling = .scaleProportionallyUpOrDown
        statusDot.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
        v.addSubview(statusDot)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusLabel.frame = NSRect(x: margin + 22, y: 338, width: contentWidth - 22, height: 22)
        v.addSubview(statusLabel)

        // Primary toggle button — default style (accent-colored)
        let buttonWidth: CGFloat = 200
        toggleButton = NSButton(title: "Enable", target: self, action: #selector(didTapToggle))
        toggleButton.bezelStyle = .rounded
        toggleButton.keyEquivalent = "\r"
        toggleButton.frame = NSRect(x: (420 - buttonWidth) / 2, y: 284, width: buttonWidth, height: 32)
        v.addSubview(toggleButton)

        // Helper tip
        let tip = NSTextField(labelWithString: "Or click the menu bar icon to toggle anytime.")
        tip.font = .systemFont(ofSize: 11)
        tip.textColor = .secondaryLabelColor
        tip.alignment = .center
        tip.frame = NSRect(x: margin, y: 256, width: contentWidth, height: 16)
        v.addSubview(tip)

        // Info banner — explains lid-closed behavior
        let bannerHeight: CGFloat = 56
        let bannerY: CGFloat = 180
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

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: margin, y: 158, width: contentWidth, height: 1)
        v.addSubview(sep)

        // Section header
        let section = NSTextField(labelWithString: "STARTUP")
        section.font = .systemFont(ofSize: 11, weight: .semibold)
        section.textColor = .secondaryLabelColor
        section.frame = NSRect(x: margin, y: 130, width: contentWidth, height: 14)
        v.addSubview(section)

        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login",
                                         target: self,
                                         action: #selector(didToggleLaunchAtLogin))
        launchAtLoginCheckbox.frame = NSRect(x: margin, y: 100, width: contentWidth, height: 22)
        v.addSubview(launchAtLoginCheckbox)

        activateOnStartCheckbox = NSButton(checkboxWithTitle: "Prevent sleep on launch",
                                            target: self,
                                            action: #selector(didToggleActivateOnStart))
        activateOnStartCheckbox.frame = NSRect(x: margin, y: 72, width: contentWidth, height: 22)
        v.addSubview(activateOnStartCheckbox)

        // Uninstall — subtle, bottom-right
        let uninstallWidth: CGFloat = 170
        let uninstallButton = NSButton(title: "Uninstall StayAwake\u{2026}",
                                       target: self,
                                       action: #selector(didTapUninstall))
        uninstallButton.bezelStyle = .recessed
        uninstallButton.controlSize = .small
        uninstallButton.contentTintColor = .systemRed
        uninstallButton.frame = NSRect(x: 420 - margin - uninstallWidth,
                                        y: 22, width: uninstallWidth, height: 22)
        v.addSubview(uninstallButton)
    }

    func refreshState() {
        launchAtLoginCheckbox.state = loginItemManager.isEnabled ? .on : .off
        activateOnStartCheckbox.state = UserDefaults.standard.bool(forKey: "activateOnStart") ? .on : .off
        applyStatus(active: sleepManager.isPreventingSleep)
    }

    private func applyStatus(active: Bool) {
        toggleButton.title = active ? "Disable" : "Enable"
        statusLabel.stringValue = active ? "Sleep prevented" : "Sleep allowed"
        statusDot.contentTintColor = active ? .systemGreen : .tertiaryLabelColor
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

    @objc private func didTapToggle() {
        sleepManager.toggle { [weak self] nowActive in
            self?.statusBarManager?.updateIcon(active: nowActive)
            self?.applyStatus(active: nowActive)
        }
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
