import IOKit.pwr_mgt
import Foundation

final class SleepManager {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isPreventingSleep = false

    @discardableResult
    func enableSleepPrevention() -> Bool {
        guard assertionID == 0 else { return true }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "StayAwake: User requested sleep prevention" as CFString,
            &assertionID
        )
        isPreventingSleep = (result == kIOReturnSuccess)
        return isPreventingSleep
    }

    func disableSleepPrevention() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isPreventingSleep = false
    }

    func toggle() -> Bool {
        if isPreventingSleep {
            disableSleepPrevention()
            return false
        } else {
            return enableSleepPrevention()
        }
    }
}
