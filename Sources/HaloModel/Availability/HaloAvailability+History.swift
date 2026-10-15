// Availability/HaloAvailability+History.swift: whether Undo and Redo can act
// now. W0 stub: neither is built yet (#208); `history-files` replaces this
// file whole when they work. Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func historyHelp(_ command: HaloCommand) -> String? {
        "Not built yet (#208)."
    }
}
