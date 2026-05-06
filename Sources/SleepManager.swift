import Foundation

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

    @discardableResult
    func enableSleepPrevention() -> Bool {
        guard runPmsetWithAdmin(value: 1) else { return isPreventingSleep }
        isPreventingSleep = true
        return true
    }

    @discardableResult
    func disableSleepPrevention() -> Bool {
        guard runPmsetWithAdmin(value: 0) else { return isPreventingSleep }
        isPreventingSleep = false
        return false
    }

    func toggle() -> Bool {
        if isPreventingSleep {
            disableSleepPrevention()
        } else {
            enableSleepPrevention()
        }
        return isPreventingSleep
    }

    private func runPmsetWithAdmin(value: Int) -> Bool {
        let prompt = value == 1
            ? "StayAwake wants to disable system sleep"
            : "StayAwake wants to re-enable system sleep"
        let source = """
        do shell script "/usr/bin/pmset -a disablesleep \(value)" with prompt "\(prompt)" with administrator privileges
        """
        guard let script = NSAppleScript(source: source) else { return false }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        return errorInfo == nil
    }
}
