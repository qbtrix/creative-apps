// Availability/HaloAvailability+Files.swift: whether Open…, Open Recent,
// Save and Save As… can act now (#209). None acts while a project is opening;
// Save and Save As… need a composition to write; Open Recent needs a project
// in the suite's recents (the file flow's list). Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func filesHelp(_ command: HaloCommand) -> String? {
        if file.opening { return "A project is opening." }
        switch command {
        case .save, .saveAs:
            return compositions.isEmpty ? "Create a composition first." : nil
        case .openRecent:
            return fileFlow.recents.isEmpty ? "No recent projects." : nil
        default:
            return nil
        }
    }
}
