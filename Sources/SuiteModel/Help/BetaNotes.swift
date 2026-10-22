// BetaNotes.swift (report-problem RP-1 stub, RP-4 body): the build's known issues, which Help > Beta Notes
// lists and `afterglow run suite help.beta-notes` prints. Linux-safe.

/// The build's known issues.
public enum BetaNotes {
    /// Each known issue's title and detail, in the order Beta Notes lists them.
    public static let current: [(title: String, detail: String)] = [
        ("This is a beta",
         "Keep a copy of work you care about. File formats can still change before the first release."),
        ("Crash reports stay on your Mac",
         "AfterGlow sends nothing by itself. Help > Report a Problem… builds a report you read, then copy, save or email."),
        ("Save often",
         "Not every app autosaves yet, so a crash can lose the edits since your last save."),
        ("Some tools are still disabled",
         "A tool or menu item that can't act yet is dimmed, and its tooltip says why."),
    ]
}
