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
        statusBarManager?.updateIcon(active: sleepManager.isPreventingSleep)

        if UserDefaults.standard.bool(forKey: "activateOnStart") && !sleepManager.isPreventingSleep {
            sleepManager.enable { [weak self] active in
                self?.statusBarManager?.updateIcon(active: active)
            }
        }
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
