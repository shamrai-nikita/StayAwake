import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    let sleepManager = SleepManager()
    let loginItemManager = LoginItemManager()
    var statusBarManager: StatusBarManager?
    var preferencesWindowController: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusBarManager = StatusBarManager(
            sleepManager: sleepManager,
            onPreferences: { [weak self] in self?.showPreferences() },
            onQuit: { NSApp.terminate(nil) }
        )

        if UserDefaults.standard.bool(forKey: "activateOnStart") {
            sleepManager.enableSleepPrevention()
            statusBarManager?.updateIcon(active: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        sleepManager.disableSleepPrevention()
    }

    private func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(
                sleepManager: sleepManager,
                loginItemManager: loginItemManager,
                statusBarManager: statusBarManager
            )
        }
        preferencesWindowController?.refreshState()
        preferencesWindowController?.showWindow(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
