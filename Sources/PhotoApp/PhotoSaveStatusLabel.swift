// PhotoSaveStatusLabel.swift: the save status `photo.bar.saved` in the status
// slot beside the status bar; the window's subtitle mirrors its title. The
// status is the `photoSaveStatus` PhotoFileArea puts in the environment, drawn
// by SuiteUI's EditorSaveStatus (`editorState` maps it), nothing with no
// image; its tooltip (PhotoSaveStatus.help) says what each means and what to
// do next.
import PhotoModel
import SuiteUI
import SwiftUI

extension PhotoSaveStatus {
    /// SuiteUI's EditorSaveStatus state: an autosaved edit is still unsaved.
    var editorState: EditorSaveStatus.State {
        switch self {
        case .saved: .saved
        case .edited, .editedAutosaved: .edited
        case .notSaved: .notSaved
        }
    }
}

extension EnvironmentValues {
    /// The window's save status for the status slot and the subtitle; nil with no image open.
    var photoSaveStatus: PhotoSaveStatus? {
        get { self[PhotoSaveStatusKey.self] }
        set { self[PhotoSaveStatusKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, as PhotoMenuKey.
private struct PhotoSaveStatusKey: EnvironmentKey {
    static let defaultValue: PhotoSaveStatus? = nil
}
