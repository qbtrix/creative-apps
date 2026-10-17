// DesignSaveStatus.swift: the slot for the save state. Until files-history fills it,
// the window subtitle stays empty and the status line's save label reads nothing; the
// `design.status.save` id is already in place for it. Views call these, never compute
// the text themselves.
import DesignModel

enum DesignSaveStatus {
    /// The window subtitle; nil until files-history reports an unsaved state.
    static func subtitle(_ model: DesignWorkspace) -> String? { nil }

    /// The status line's save label; empty until files-history.
    static func label(_ model: DesignWorkspace) -> String { "" }
}
