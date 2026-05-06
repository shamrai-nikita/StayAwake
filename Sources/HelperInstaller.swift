import Cocoa

enum HelperInstaller {
    static let sudoersPath = "/etc/sudoers.d/stayawake"

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: sudoersPath)
    }

    @discardableResult
    static func installIfNeeded() -> Bool {
        if isInstalled { return true }

        let alert = NSAlert()
        alert.messageText = "Set up StayAwake"
        alert.informativeText = """
        StayAwake needs one-time admin permission to install a small helper that lets pmset run as root.

        After this, every toggle will use Touch ID — no more password prompts.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Set Up")
        alert.addButton(withTitle: "Skip")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return false
        }

        return runInstallScript()
    }

    private static func runInstallScript() -> Bool {
        let user = NSUserName()
        let sudoersLine = "\(user) ALL=(ALL) NOPASSWD: /usr/bin/pmset\n"

        let tempPath = NSTemporaryDirectory().appending("stayawake.sudoers")
        do {
            try sudoersLine.write(toFile: tempPath, atomically: true, encoding: .utf8)
        } catch {
            return false
        }

        let shellCmd = "/bin/mv '\(tempPath)' '\(sudoersPath)' && /bin/chmod 0440 '\(sudoersPath)' && /usr/sbin/visudo -c -f '\(sudoersPath)'"
        let escaped = shellCmd
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScriptSource = """
        do shell script "\(escaped)" with prompt "Install StayAwake helper" with administrator privileges
        """

        var err: NSDictionary?
        NSAppleScript(source: appleScriptSource)?.executeAndReturnError(&err)

        if err != nil {
            try? FileManager.default.removeItem(atPath: tempPath)
            return false
        }
        return isInstalled
    }
}
