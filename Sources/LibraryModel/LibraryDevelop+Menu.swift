// LibraryDevelop+Menu.swift: when the Develop menu's actions can run (feature
// develop, DV-8). The window's develop area reads these instead of working
// out its enable rules itself. `developMenuRules` holds the rules over plain
// inputs so they are testable while DV-3 fills `developTargets` and
// `developHelp`. Linux-safe.

/// Which Develop actions can run now.
public struct DevelopMenuRules: Equatable, Sendable {
    /// An edit, reset or paste can act: no help is showing and there is a target.
    public let canEdit: Bool
    /// Show Original can act: an edit can, and the loupe shows a photo.
    public let canShowOriginal: Bool
    /// Copy Settings can act: exactly one target.
    public let canCopySettings: Bool
}

extension LibraryCatalog {
    /// The rules for `help` (nil when editing is allowed), `targetCount` targets and whether the loupe shows a photo.
    static func developMenuRules(help: String?, targetCount: Int, loupeShowsPhoto: Bool) -> DevelopMenuRules {
        let canEdit = help == nil && targetCount > 0
        return DevelopMenuRules(
            canEdit: canEdit,
            canShowOriginal: canEdit && loupeShowsPhoto,
            canCopySettings: targetCount == 1)
    }

    /// The Develop menu's rules for this catalog.
    var developMenuRules: DevelopMenuRules {
        Self.developMenuRules(
            help: developHelp,
            targetCount: developTargets.count,
            loupeShowsPhoto: mode == .loupe && loupeItem != nil)
    }

    /// No develop help is showing and there is at least one target.
    public var canEditDevelop: Bool { developMenuRules.canEdit }
    /// Develop edits can act and the loupe is showing a photo.
    public var canShowOriginal: Bool { developMenuRules.canShowOriginal }
    /// Exactly one develop target, the photo Copy Settings reads.
    public var canCopySettings: Bool { developMenuRules.canCopySettings }
}
