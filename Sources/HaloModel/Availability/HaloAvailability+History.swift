// Availability/HaloAvailability+History.swift: whether Undo and Redo can act
// now (#208). Both are off while a project opens, then while the history
// service says it can't act, then while their stack is empty. Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func historyHelp(_ command: HaloCommand) -> String? {
        if file.opening { return "A project is opening." }
        if let help = services.history.unavailableHelp { return help }
        switch command {
        case .undo: return history.undo.isEmpty ? "Nothing to undo." : nil
        case .redo: return history.redo.isEmpty ? "Nothing to redo." : nil
        default: return nil
        }
    }
}
