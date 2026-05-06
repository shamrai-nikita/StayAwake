import Foundation
import LocalAuthentication
import Cocoa
import IOKit.pwr_mgt

extension Notification.Name {
    static let sleepStateChanged = Notification.Name("StayAwake.sleepStateChanged")
}

final class SleepManager {
    static let requireTouchIDKey = "requireTouchID"

    private(set) var isPreventingSleep = false
    private(set) var expiresAt: Date?

    private var expiryTimer: DispatchSourceTimer?
    private var displayAssertionID: IOPMAssertionID?

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
        if !isPreventingSleep {
            cancelTimer()
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

    func enableForDuration(_ seconds: TimeInterval, completion: @escaping (Bool) -> Void) {
        setValue(1) { [weak self] active in
            guard let self = self else { completion(false); return }
            if active {
                self.scheduleExpiry(after: seconds)
            }
            completion(active)
        }
    }

    func cancelTimer() {
        expiryTimer?.cancel()
        expiryTimer = nil
        if expiresAt != nil {
            expiresAt = nil
            broadcastStateChange()
        }
    }

    private func scheduleExpiry(after seconds: TimeInterval) {
        expiryTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + seconds)
        timer.setEventHandler { [weak self] in
            self?.handleTimerFired()
        }
        expiresAt = Date().addingTimeInterval(seconds)
        expiryTimer = timer
        timer.resume()
        broadcastStateChange()
    }

    private func handleTimerFired() {
        expiryTimer = nil
        expiresAt = nil
        // Bypass auth on auto-expiry — user already authorised at activation,
        // and a Touch ID prompt would just hang if they walked away.
        if runPmsetSilent(value: 0) {
            isPreventingSleep = false
        }
        broadcastStateChange()
    }

    private func setValue(_ value: Int, completion: @escaping (Bool) -> Void) {
        // Manual transitions cancel any running timer.
        if expiryTimer != nil {
            expiryTimer?.cancel()
            expiryTimer = nil
            expiresAt = nil
        }

        let requireAuth = UserDefaults.standard.bool(forKey: Self.requireTouchIDKey)
        let reason = value == 1 ? "disable system sleep" : "re-enable system sleep"

        let proceed: () -> Void = { [weak self] in
            guard let self = self else { return }
            if self.runPmsetSilent(value: value) {
                self.isPreventingSleep = (value == 1)
                self.broadcastStateChange()
                completion(self.isPreventingSleep)
                return
            }
            DispatchQueue.main.async {
                if HelperInstaller.installIfNeeded(), self.runPmsetSilent(value: value) {
                    self.isPreventingSleep = (value == 1)
                    self.broadcastStateChange()
                }
                completion(self.isPreventingSleep)
            }
        }

        if requireAuth {
            authenticate(reason: reason) { authed in
                guard authed else {
                    completion(self.isPreventingSleep)
                    return
                }
                proceed()
            }
        } else {
            proceed()
        }
    }

    private func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var laError: NSError?
        let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics

        guard context.canEvaluatePolicy(policy, error: &laError) else {
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

    private func broadcastStateChange() {
        NotificationCenter.default.post(name: .sleepStateChanged, object: self)
    }

    private func acquireDisplayAssertion() {
        guard displayAssertionID == nil else { return }
        var newID: IOPMAssertionID = 0
        let reason = "StayAwake is preventing system sleep" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &newID
        )
        if result == kIOReturnSuccess {
            displayAssertionID = newID
        } else {
            NSLog("StayAwake: IOPMAssertionCreateWithName failed (0x%x)", result)
        }
    }

    private func releaseDisplayAssertion() {
        guard let id = displayAssertionID else { return }
        IOPMAssertionRelease(id)
        displayAssertionID = nil
    }
}
