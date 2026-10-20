// RunLoopWait.swift: the one way a SuiteUITests test waits for a hosted view.
// `spinUntil` turns the main run loop until the condition holds or the timeout
// passes, so a test waits for what it reads (an accessibility node, a callback)
// instead of a fixed delay that a loaded machine overruns. The test's own
// assertions stay as strict as before; this only decides when to look.
import Foundation

/// Turns the main run loop until `condition` is true; false if `timeout` passes first.
@MainActor @discardableResult
func spinUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() >= deadline { return false }
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    return true
}
