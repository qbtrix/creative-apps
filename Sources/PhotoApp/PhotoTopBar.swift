// PhotoTopBar.swift: the Photo window's top bar on SuiteUI's EditorTopBar:
// the document menu (New Image, Open…, Save, Save As…, Export…), the save
// status, then Open, Save, Export, the Image menu, Undo and Redo, then zoom.
// The status (`photo.bar.saved`) is the `photoSaveStatus` PhotoFileArea puts
// in the environment, drawn plain until SuiteUI's EditorSaveStatus (EC-4,
// #339) lands: "Saved" in textSecondary, an accent dot and "Edited" while
// unsaved, a triangle and "Not saved" in stateError after a failed save, and
// nothing with no image; its tooltip (PhotoSaveStatus.help) says what each
// means and what to do next. A command that
// can't act now is disabled with a tooltip saying why; each carries a
// `photo.bar.*` accessibility identifier for the UI journeys and the app
// audit, and Undo and Redo keep theirs whatever edit they name.
import PhotoModel
import SuiteUI
import SwiftUI

/// The top bar: the document menu, Open, Save, Export, the Image menu, Undo
/// and Redo, then zoom.
struct PhotoTopBar: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    /// The window's save status from PhotoFileArea; nil with no image or outside a window.
    @Environment(\.photoSaveStatus) private var saveStatus

    var body: some View {
        let noImage = model.canvas == nil ? "Open or create an image first." : nil
        EditorTopBar(app: "Photo", document: model.canvas == nil ? nil : model.documentName ?? "Untitled") {
            Button("New Image") { perform(.newImage) }.accessibilityIdentifier("photo.bar.document.new")
            Button("Open…") { perform(.open) }.accessibilityIdentifier("photo.bar.document.open")
            Divider()
            Button("Save") { perform(.save) }.disabled(noImage != nil).accessibilityIdentifier("photo.bar.document.save")
            Button("Save As…") { perform(.saveAs) }.disabled(noImage != nil).accessibilityIdentifier("photo.bar.save-as")
            Button("Export…") { perform(.export(.openSheet)) }.disabled(noImage != nil)
                .accessibilityIdentifier("photo.bar.document.export")
        } content: {
            if let saveStatus {
                PhotoSaveStatusLabel(status: saveStatus, fileName: model.documentName)
                EditorBarDivider()
            }
            EditorBarItem(ToolbarAction("Open", systemImage: "folder") { perform(.open) })
                .accessibilityIdentifier("photo.bar.open")
            EditorBarItem(ToolbarAction("Save", systemImage: "square.and.arrow.down", unavailableHelp: noImage) {
                perform(.save)
            })
            .accessibilityIdentifier("photo.bar.save")
            EditorBarItem(ToolbarAction("Export", systemImage: "square.and.arrow.up", unavailableHelp: noImage) {
                perform(.export(.openSheet))
            })
            .accessibilityIdentifier("photo.bar.export")
            EditorBarMenu("Image", systemImage: "photo", unavailableHelp: noImage) {
                PhotoImageMenu(perform: perform)
            }
            .accessibilityIdentifier("photo.bar.image")
            EditorBarDivider()
            EditorBarItem(
                ToolbarAction(
                    model.undoActionName, systemImage: "arrow.uturn.backward",
                    unavailableHelp: model.canUndo ? nil : "Nothing to undo.") { perform(.undo) },
                showsTitle: false)
            .accessibilityIdentifier("photo.bar.undo")
            EditorBarItem(
                ToolbarAction(
                    model.redoActionName, systemImage: "arrow.uturn.forward",
                    unavailableHelp: model.canRedo ? nil : "Nothing to redo.") { perform(.redo) },
                showsTitle: false)
            .accessibilityIdentifier("photo.bar.redo")
            Spacer(minLength: SuiteSpacing.s)
            EditorBarItem(
                ToolbarAction("Zoom Out", systemImage: "minus.magnifyingglass", unavailableHelp: noImage) {
                    perform(.zoomOut)
                }, showsTitle: false)
            .accessibilityIdentifier("photo.bar.zoom-out")
            EditorBarItem(
                ToolbarAction("Fit on Screen", systemImage: "arrow.up.left.and.arrow.down.right", unavailableHelp: noImage) {
                    perform(.fit)
                }, showsTitle: false)
            .accessibilityIdentifier("photo.bar.fit")
            EditorBarItem(
                ToolbarAction("Zoom In", systemImage: "plus.magnifyingglass", unavailableHelp: noImage) {
                    perform(.zoomIn)
                }, showsTitle: false)
            .accessibilityIdentifier("photo.bar.zoom-in")
        }
    }
}

/// `photo.bar.saved`: the save status as plain text with its cue, a stand-in
/// for SuiteUI's EditorSaveStatus (EC-4). Its label and value are the title
/// (journeys read the label); its tooltip and hint say what the status means
/// for `fileName` and what to do next. Inset like a bar button, so it sits
/// centered between its dividers.
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
    /// The window's save status for the top bar; nil with no image open.
    var photoSaveStatus: PhotoSaveStatus? {
        get { self[PhotoSaveStatusKey.self] }
        set { self[PhotoSaveStatusKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, as PhotoMenuKey.
private struct PhotoSaveStatusKey: EnvironmentKey {
    static let defaultValue: PhotoSaveStatus? = nil
}
