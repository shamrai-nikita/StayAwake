import Cocoa

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private let sleepManager: SleepManager
    private let loginItemManager: LoginItemManager
    weak var statusBarManager: StatusBarManager?

    private var launchAtLoginCheckbox: NSButton!
    private var activateOnStartCheckbox: NSButton!
    private var toggleButton: NSButton!

    init(sleepManager: SleepManager,
         loginItemManager: LoginItemManager,
         statusBarManager: StatusBarManager?) {
        self.sleepManager = sleepManager
        self.loginItemManager = loginItemManager
        self.statusBarManager = statusBarManager

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
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

        let title = NSTextField(labelWithString: "StayAwake")
        title.font = .boldSystemFont(ofSize: 18)
        title.frame = NSRect(x: 20, y: 255, width: 380, height: 26)
        v.addSubview(title)

        let desc = NSTextField(wrappingLabelWithString: "Click the menu bar icon to prevent your Mac from sleeping\u{2014}even when the lid is closed.")
        desc.font = .systemFont(ofSize: 12)
        desc.textColor = .secondaryLabelColor
        desc.frame = NSRect(x: 20, y: 210, width: 380, height: 40)
        v.addSubview(desc)

        launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login",
                                         target: self,
                                         action: #selector(didToggleLaunchAtLogin))
        launchAtLoginCheckbox.frame = NSRect(x: 20, y: 178, width: 380, height: 22)
        v.addSubview(launchAtLoginCheckbox)

        activateOnStartCheckbox = NSButton(checkboxWithTitle: "Activate when app starts",
                                            target: self,
                                            action: #selector(didToggleActivateOnStart))
        activateOnStartCheckbox.frame = NSRect(x: 20, y: 150, width: 380, height: 22)
        v.addSubview(activateOnStartCheckbox)

        let sep = NSBox()
        sep.boxType = .separator
        sep.frame = NSRect(x: 20, y: 128, width: 380, height: 1)
        v.addSubview(sep)

        toggleButton = NSButton(title: "Enable", target: self, action: #selector(didTapToggle))
        toggleButton.bezelStyle = .rounded
        toggleButton.frame = NSRect(x: 20, y: 84, width: 120, height: 32)
        v.addSubview(toggleButton)

        let quitBtn = NSButton(title: "Quit", target: self, action: #selector(didTapQuit))
        quitBtn.bezelStyle = .rounded
        quitBtn.frame = NSRect(x: 320, y: 84, width: 80, height: 32)
        v.addSubview(quitBtn)

        let sep2 = NSBox()
        sep2.boxType = .separator
        sep2.frame = NSRect(x: 20, y: 64, width: 380, height: 1)
        v.addSubview(sep2)

        let uninstallButton = NSButton(title: "Uninstall StayAwake\u{2026}",
                                       target: self,
                                       action: #selector(didTapUninstall))
        uninstallButton.bezelStyle = .rounded
        uninstallButton.frame = NSRect(x: 20, y: 20, width: 200, height: 32)
        uninstallButton.contentTintColor = .systemRed
        v.addSubview(uninstallButton)
    }

    func refreshState() {
        launchAtLoginCheckbox.state = loginItemManager.isEnabled ? .on : .off
        activateOnStartCheckbox.state = UserDefaults.standard.bool(forKey: "activateOnStart") ? .on : .off
        toggleButton.title = sleepManager.isPreventingSleep ? "Disable" : "Enable"
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
            self?.toggleButton.title = nowActive ? "Disable" : "Enable"
        }
    }

    @objc private func didTapQuit() {
        NSApp.terminate(nil)
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
