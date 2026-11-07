// FlareFilePanels.swift: the file area's window side (FlareWindow+File.swift
// does the reads and writes). The modifier keeps the window's edited dot
// (NSWindow.isDocumentEdited) on `model.isDirty` through a window accessor,
// carries the same state as the hidden `flare.file` element's label ("Edited"
// or "Saved"; XCUITest reads no edited dot), shows a failed save's `saveError`
// or a failed open's `loadState` message in a system alert each time the
// Model sets it again, and opens `-FlareOpenFile`'s file once, in the first
// window, the way Open Recent does. FlareFileDialogs are the AppKit panels:
// open for .flare and Lottie JSON files, save for .flare files and the
// export's folder. Save, Don't Save and Cancel before a dirty animation goes
// are SuiteUI's unsaved guard (FlareWindow.swift, `unsavedHooks`).
// The window title is SuiteWindow's (`model.title`).
import AppKit
import FlareModel
import SuiteUI
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
                ProbeElement("flare.file", label: edited ? "Edited" : "Saved", value: edited ? "Edited" : "Saved")
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

/// The open, save and folder panels.
@MainActor enum FlareFileDialogs {
    /// The `.flare` extension as the system types a file on disk.
    static let fileType = UTType(filenameExtension: "flare") ?? .data

    /// The open panel, for one .flare or Lottie JSON file (`FlareLottieOpen.fileExtensions`); nil when cancelled.
    static func chooseFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [fileType] + FlareLottieOpen.fileExtensions.compactMap { UTType(filenameExtension: $0) }
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

    /// The folder panel for an export; nil when cancelled.
    static func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
