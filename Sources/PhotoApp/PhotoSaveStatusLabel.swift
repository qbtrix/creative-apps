// PhotoSaveStatusLabel.swift: the save status `photo.bar.saved` in the status
// slot beside PhotoStatusLine; the window's subtitle mirrors its title. The
// status is the `photoSaveStatus` PhotoFileArea puts in the environment,
// drawn plain until SuiteUI's EditorSaveStatus (EC-4, #339) lands: "Saved" in
// textSecondary, an accent dot and "Edited" while unsaved, a triangle and
// "Not saved" in stateError after a failed save, and nothing with no image;
// its tooltip (PhotoSaveStatus.help) says what each means and what to do next.
import PhotoModel
import SuiteUI
import SwiftUI

/// `photo.bar.saved`: the save status as plain text with its cue, a stand-in
/// for SuiteUI's EditorSaveStatus (EC-4). Its label and value are the title
/// (journeys read the label); its tooltip and hint say what the status means
/// for `fileName` and what to do next. Inset like a bar button, so it sits
/// apart from the status line beside it.
struct PhotoSaveStatusLabel: View {
    let status: PhotoSaveStatus
    /// The document's file name; nil for an image never saved.
    let fileName: String?

    var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            switch status {
            case .saved: EmptyView()
            case .edited, .editedAutosaved:
                Image(systemName: "circle.fill")
                    .resizable()
                    .frame(width: SuiteSize.statusDot, height: SuiteSize.statusDot)
                    .foregroundStyle(SuiteColor.accent)
            case .notSaved: Image(systemName: "exclamationmark.triangle.fill")
            }
            Text(status.title)
        }
        .foregroundStyle(status == .notSaved ? SuiteColor.stateError : SuiteColor.textSecondary)
        .padding(SuiteInset.barButton)
        .fixedSize()
        .help(status.help(fileName: fileName))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.title)
        .accessibilityValue(status.title)
        .accessibilityHint(status.help(fileName: fileName))
        .accessibilityIdentifier("photo.bar.saved")
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
