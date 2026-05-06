import Foundation
import LocalAuthentication
import Cocoa

final class SleepManager {
    private(set) var isPreventingSleep = false

    init() {
        refreshState()
    }

    func refreshState() {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["-g"]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            isPreventingSleep = Self.parseSleepDisabled(output)
        } catch {
            isPreventingSleep = false
        }
    }

    private static func parseSleepDisabled(_ output: String) -> Bool {
        for raw in output.split(separator: "\n") {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if lower.hasPrefix("sleepdisabled") || lower.hasPrefix("disablesleep") {
                return trimmed.last == "1"
            }
        }
        return false
    }

    func toggle(completion: @escaping (Bool) -> Void) {
        if isPreventingSleep {
            setValue(0, completion: completion)
        } else {
            setValue(1, completion: completion)
        }
    }

    func enable(completion: @escaping (Bool) -> Void) {
        setValue(1, completion: completion)
    }

    private func setValue(_ value: Int, completion: @escaping (Bool) -> Void) {
        let reason = value == 1 ? "disable system sleep" : "re-enable system sleep"
        authenticate(reason: reason) { [weak self] authed in
            guard let self = self else { return }
            guard authed else {
                completion(self.isPreventingSleep)
                return
            }
            if self.runPmsetSilent(value: value) {
                self.isPreventingSleep = (value == 1)
                completion(self.isPreventingSleep)
            } else {
                self.showHelperMissingAlert()
                completion(self.isPreventingSleep)
            }
        }
    }

    private func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var laError: NSError?
        let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics

        guard context.canEvaluatePolicy(policy, error: &laError) else {
            // Fall back to password-based device-owner auth if biometrics unavailable.
            let fallback = LAContext()
            var fallbackError: NSError?
            guard fallback.canEvaluatePolicy(.deviceOwnerAuthentication, error: &fallbackError) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            fallback.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
                DispatchQueue.main.async { completion(ok) }
            }
            return
        }

        context.evaluatePolicy(policy, localizedReason: reason) { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    private func runPmsetSilent(value: Int) -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", String(value)]
        let nullPipe = Pipe()
        task.standardOutput = nullPipe
        task.standardError = nullPipe
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func showHelperMissingAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Touch ID helper not installed"
            alert.informativeText = "Run `make install-helper` in the project directory once to enable passwordless toggle.\n\n(Without it, pmset cannot run as root from the app.)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
