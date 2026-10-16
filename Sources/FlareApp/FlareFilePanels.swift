// FlareFilePanels.swift: the file area's window side (FlareWindow+File.swift
// does the reads and writes). The modifier keeps the window's edited dot
// (NSWindow.isDocumentEdited) on `model.isDirty` through a window accessor,
// carries the same state as the hidden `flare.file` element's label ("Edited"
// or "Saved"; XCUITest reads no edited dot), shows a failed save's `saveError`
// or a failed open's `loadState` message in a system alert each time the
// Model sets it again, and opens `-FlareOpenFile`'s file once, in the first
// window, the way Open Recent does. FlareFileDialogs are the AppKit panels:
// open and save for .flare files, and the close prompt's Save, Don't Save
// and Cancel. The window title is SuiteWindow's (`model.title`).
import AppKit
import FlareModel
import SwiftUI
import UniformTypeIdentifiers

struct FlareFilePanels: ViewModifier {
    let model: FlareWorkspace
    let launch: FlareLaunch
    let perform: @MainActor (FlareIntent) -> Void
    @State private var shown: String?

    private var openFailure: String? {
        if case .failed(let message) = model.loadState { message } else { nil }
    }

    func body(content: Content) -> some View {
        let edited = model.document != nil && model.isDirty
        content
            .background {
                FlareEditedDot(edited: edited)
                FlareFileElement(status: edited ? "Edited" : "Saved")
            }
            .alert(shown ?? "", isPresented: Binding(get: { shown != nil }, set: { if !$0 { shown = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .onChange(of: model.saveError) { _, new in if let new { shown = new } }
            .onChange(of: openFailure) { _, new in if let new { shown = new } }
            .task {
                guard !FlareLaunchFile.opened, case .file(let path) = launch.source else { return }
                FlareLaunchFile.opened = true
                perform(.file(.openRecent(path: path)))
            }
    }
}

/// Whether this process has opened `-FlareOpenFile` (only the first window does).
@MainActor private enum FlareLaunchFile {
    static var opened = false
}

/// The window accessor: sets its window's edited dot.
private struct FlareEditedDot: NSViewRepresentable {
    let edited: Bool

    func makeNSView(context: Context) -> FlareEditedView { FlareEditedView() }

    func updateNSView(_ view: FlareEditedView, context: Context) { view.edited = edited }
}

final class FlareEditedView: NSView {
    var edited = false {
        didSet { window?.isDocumentEdited = edited }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isDocumentEdited = edited
    }
}

/// The hidden `flare.file` element: no hits, its label the edited state.
private struct FlareFileElement: View {
    let status: String

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(status)
            .accessibilityValue(status)
            .accessibilityIdentifier("flare.file")
    }
}

/// The open and save panels and the close prompt.
@MainActor enum FlareFileDialogs {
    enum Choice { case save, discard, cancel }

    /// The `.flare` extension as the system types a file on disk.
    static let fileType = UTType(filenameExtension: "flare") ?? .data

    /// The open panel, for one .flare file; nil when cancelled.
    static func chooseFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [fileType]
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// The save panel, starting at `name`; nil when cancelled.
    static func chooseSaveURL(named name: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [fileType]
        panel.nameFieldStringValue = name
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Asks whether to save `title`'s changes before it closes: a sheet on
    /// `window`, or a dialog without one.
    static func askToSave(_ title: String, in window: NSWindow?) async -> Choice {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Do you want to save the changes made to \u{201C}\(title)\u{201D}?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save").setAccessibilityIdentifier("flare.close.save")
        alert.addButton(withTitle: "Don't Save").setAccessibilityIdentifier("flare.close.discard")
        alert.addButton(withTitle: "Cancel").setAccessibilityIdentifier("flare.close.cancel")
        let response = if let window { await alert.beginSheetModal(for: window) } else { alert.runModal() }
        switch response {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }
}
