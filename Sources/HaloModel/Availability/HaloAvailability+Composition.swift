// Availability/HaloAvailability+Composition.swift: whether the composition
// commands (shipped) can act now. They answer from state only: New always
// can; Duplicate and Delete need a selected composition, and Delete never
// removes the last one; select and rename need the composition to exist (a
// rename to a bad name still runs and shows its refusal). Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func compositionHelp(_ command: HaloCommand) -> String? {
        switch command {
        case .duplicateComposition:
            return selectedComposition == nil ? HaloEditError.noComposition.message : nil
        case .deleteComposition:
            if selectedComposition == nil { return HaloEditError.noComposition.message }
            return canDeleteComposition ? nil : "A project keeps at least one composition."
        case .selectComposition(let id), .renameComposition(let id, _):
            if compositions.isEmpty { return HaloEditError.noComposition.message }
            return compositions.contains { $0.id == id } ? nil : "The composition no longer exists."
        default:
            return nil
        }
    }
}
