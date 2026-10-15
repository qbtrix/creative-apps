// Availability/HaloAvailability+Files.swift: whether Open…, Open Recent,
// Save and Save As… can act now. W0 stub: none is built yet (#209);
// `history-files` replaces this file whole when they work. Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func filesHelp(_ command: HaloCommand) -> String? {
        "Not built yet (#209)."
    }
}
