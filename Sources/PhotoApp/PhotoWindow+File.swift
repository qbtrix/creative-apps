// PhotoWindow+File.swift: the file area of a Photo window (photo-documents,
// PV-1): its intents, its route, its hook on the window, the services the
// window runs on, and open, Save, Save As and the writes they share. New
// Image, Open, Save and Save As route through PhotoWindow.perform to the
// helpers here; Keep layers?' choices and Clear Menu are FileIntents. Save
// goes where `model.saveAction` says: a document is written over its `.ora`
// (PhotoPackageIO, the snapshot taken off the main actor), a flat image over
// its file, a flat file whose image has layers asks "Keep layers?" (Save as
// Photo Document writes `<name>.ora` beside it, or in `-PhotoSaveTo`'s
// folder, and makes that the file; Flatten writes the flat file), and a new
// or read-only image is Save As (the panel offers .ora, PNG and JPEG;
// `-PhotoSaveTo <folder>` writes `<name>.ora` there when the image needs a
// document, else `<name>.png`). A failed save shows "The image couldn't be
// saved: <reason>." and sets `files.saveFailed` until the image is clean.
// Open reads an `.ora` and decodes its PNGs off the main actor, then opens
// the snapshot; a bad document shows its ArchiveError message and the window
// keeps what it had. Flat files open through `openImage`, so Save knows
// their kind. Each successful open and save is noted in Open Recent.
// `-PhotoOpenFile <path>` opens a file at launch; `-PhotoRecoveryDir
// <folder>` keeps autosaves there. PhotoFileSession is the file state the
// window and PhotoFileArea share. PhotoFileArea
// puts `model.saveStatus` in the environment for the top bar's
// `photo.bar.saved`, keeps the window's edited dot (`isDocumentEdited`) on
// `model.isDirty`, and shows "Saving…" (`photo.file.saving`) or "Opening…"
// (`photo.file.opening`) over the window once `files.working` has run 100 ms.
// It runs the window's PhotoAutosave (D-9): a tick every second, discarded on
// a clean close; the first window offers what a crash left behind, and
// Restore and Discard are FileIntents. D-10: PhotoWindowEditedView is the
// window's hook for Quit and Finder opens (PhotoApp.swift); its close guard
// asks PhotoUnsavedPrompt's alert before a dirty window closes.
import AppKit
import CoreRaster
import Observation
import PhotoModel
import SuiteUI
import SwiftUI
import UniformTypeIdentifiers

/// What the file area can be asked to do.
enum FileIntent {
    /// Keep layers?: Save as Photo Document.
    case saveDocument
    /// Keep layers?: Flatten into the open file's format.
    case flatten(ImageFormat)
    /// Open Recent > Clear Menu.
    case clearRecent
    /// The launch offer: Restore its image into the window.
    case restore(RecoveryOffer)
    /// The launch offer: Discard what the crash left behind.
    case discardRecovery
}

/// Long file work running off the main actor, for the window's notes.
enum PhotoFileWork: Sendable {
    case saving, opening

    /// The note on the canvas while this runs.
    var note: String { self == .saving ? "Saving…" : "Opening…" }

    var identifier: String { self == .saving ? "photo.file.saving" : "photo.file.opening" }
}

/// The file state a window and its PhotoFileArea share.
@MainActor @Observable
final class PhotoFileSession {
    /// The flat format "Keep layers?" asks about while it is up; nil when closed.
    var keepLayers: ImageFormat?
    /// The last save failed and the image hasn't been clean since: "Not saved".
    var saveFailed = false
    /// A save or an open is running off the main actor.
    var working: PhotoFileWork?
    /// Saves that landed, so the unsaved prompt's Save knows it did.
    var saves = 0
    /// Open Recent's files, newest first.
    private(set) var recentFiles: [URL] = PhotoFileSession.storedRecent()
    /// The window's autosave, made on its workspace's recovery store when the window appears.
    private(set) var autosave: PhotoAutosave?
    /// The launch's restore offer while it waits for Restore or Discard.
    var recoveryOffer: RecoveryOffer?
    /// Only the first window of a launch looks for what a crash left behind.
    private static var recoveryChecked = false

    /// The window's autosave, made on `store` the first time.
    func startAutosave(_ store: any RecoveryStoring) -> PhotoAutosave {
        if let autosave { return autosave }
        let made = PhotoAutosave(window: UUID().uuidString, delay: PhotoWorkspace.autosaveDelay, store: store)
        autosave = made
        return made
    }

    /// The first window's launch: offers the newest autosave a crash left behind.
    func offerRecovery(_ model: PhotoWorkspace) async {
        guard !Self.recoveryChecked else { return }
        Self.recoveryChecked = true
        recoveryOffer = await startAutosave(model.services.recovery).launch(model: model)
    }

    /// Notes `url` in Open Recent: the system's list, and Photo's own (an app
    /// with no declared document types may not get the system's).
    func noteRecent(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        store(Array(([url] + recentFiles.filter { $0 != url }).prefix(10)))
    }

    func clearRecent() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        store([])
    }

    private nonisolated static let recentKey = "PhotoRecentFiles"

    private nonisolated static func storedRecent() -> [URL] {
        (UserDefaults.standard.stringArray(forKey: recentKey) ?? []).map { URL(fileURLWithPath: $0) }
    }

    private func store(_ urls: [URL]) {
        recentFiles = urls
        UserDefaults.standard.set(urls.map(\.path), forKey: Self.recentKey)
    }
}

extension PhotoWindow {
    /// The services a window runs on when no fixture is asked for: `.live`,
    /// its autosaves in `-PhotoRecoveryDir`'s folder when one is given.
    nonisolated static func fileServices(_ live: PhotoServices) -> PhotoServices {
        guard let folder = UserDefaults.standard.string(forKey: "PhotoRecoveryDir") else { return live }
        return live.recovering(in: URL(fileURLWithPath: folder, isDirectory: true))
    }

    /// The last save failed and the image is still edited (D-8's "Not saved").
    var saveFailed: Bool { files.saveFailed }

    /// The OpenRaster document type (a dynamic type while the bundle declares
    /// none); empty only if the system refuses the extension.
    static let documentTypes: [UTType] = UTType(filenameExtension: "ora", conformingTo: .data).map { [$0] } ?? []

    func performFile(_ intent: FileIntent) {
        switch intent {
        case .saveDocument:
            files.keepLayers = nil
            guard let folder = Self.saveToFolder ?? documentURL?.deletingLastPathComponent() else { return saveAs() }
            writeDocument(to: folder.appending(path: model.documentFileName))
        case .flatten(let format):
            files.keepLayers = nil
            guard let url = documentURL else { return saveAs() }
            write(to: url, as: format, quality: exportQuality, saving: true)
        case .clearRecent: files.clearRecent()
        case .restore(let offer):
            files.recoveryOffer = nil
            let autosave = files.startAutosave(model.services.recovery)
            do {
                try autosave.restore(offer, into: &model, codec: ImageIOCodec())
                documentURL = nil
            } catch {
                autosave.discardLeftBehind()  // it holds nothing to keep (packet note 3)
                problem = (error as? ArchiveError)?.message ?? "The image can't be restored. \(Self.reason(error))"
            }
        case .discardRecovery:
            files.recoveryOffer = nil
            files.startAutosave(model.services.recovery).discardLeftBehind()
        }
    }

    func openLaunchFile() {
        guard !Self.launchFileOpened, let path = UserDefaults.standard.string(forKey: "PhotoOpenFile") else { return }
        Self.launchFileOpened = true
        open(URL(fileURLWithPath: path))
    }

    func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.documentTypes + [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    func open(_ url: URL) {
        if PhotoWorkspace.fileKind(forName: url.lastPathComponent) == .document { return openDocument(url) }
        do {
            let data = try Data(contentsOf: url)
            let side = ImageIOCodec.pixelSize(of: data).flatMap {
                PhotoWorkspace.decodeLongestSide(width: $0.width, height: $0.height)
            }
            try model.openImage(data, name: url.lastPathComponent, codec: ImageIOCodec(), longestSide: side)
            documentURL = url
            files.noteRecent(url)
            note = side.map { "Opened at \($0) px on the longest side" }
        } catch {
            problem = "\(url.lastPathComponent) can't be opened. \(Self.reason(error))"
        }
    }

    /// Reads and decodes the document at `url` off the main actor, then opens
    /// it; a failure leaves the window as it was.
    private func openDocument(_ url: URL) {
        let (archive, name) = (model.services.archive, url.lastPathComponent)
        files.working = .opening
        Task {
            do {
                let package = try await PhotoPackageIO.read(from: url, archive: archive)
                let snapshot = try await Task.detached(priority: .userInitiated) {
                    try archive.decode(package, codec: ImageIOCodec())
                }.value
                try model.openDocument(snapshot, name: name)
                documentURL = url
                files.noteRecent(url)
                note = nil
            } catch let error as ArchiveError {
                problem = error.message
            } catch {
                problem = "\(name) can't be opened. \(Self.reason(error))"
            }
            files.working = nil
        }
    }

    /// File > Save, routed by `model.saveAction`.
    func save() {
        guard model.canvas != nil else { return }
        switch model.saveAction {
        case .writeDocument:
            guard let url = documentURL else { return saveAs() }
            writeDocument(to: url)
        case .writeImage(let format):
            guard let url = documentURL else { return saveAs() }
            write(to: url, as: format, quality: exportQuality, saving: true)
        case .askKeepLayers(let format): files.keepLayers = format
        case .saveAs: saveAs()
        }
    }

    /// Asks where to save: a document for a name ending in .ora, else PNG or
    /// JPEG by the extension. `-PhotoSaveTo` writes there without asking.
    func saveAs() {
        guard model.canvas != nil else { return }
        if let folder = Self.saveToFolder {
            if model.needsDocument { return writeDocument(to: folder.appending(path: model.documentFileName)) }
            return write(to: folder.appending(path: model.fileName(for: .png)), as: .png, quality: exportQuality, saving: true)
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = Self.documentTypes + [.png, .jpeg]
        panel.nameFieldStringValue = model.needsDocument
            ? model.documentFileName : model.fileName(for: ImageFormat(fileName: model.documentName ?? "") ?? .png)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if PhotoWorkspace.fileKind(forName: url.lastPathComponent) == .document { return writeDocument(to: url) }
        write(to: url, as: ImageFormat(fileName: url.lastPathComponent) ?? .png, quality: exportQuality, saving: true)
    }

    /// `-PhotoSaveTo`'s folder, when given.
    private static var saveToFolder: URL? {
        UserDefaults.standard.string(forKey: "PhotoSaveTo").map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Writes the image as a document at `url`: the snapshot and the write
    /// both run off the main actor, then `url` is the window's file.
    private func writeDocument(to url: URL) {
        let (workspace, opened) = (model, documentURL)
        note = "Saving…"
        files.working = .saving
        Task {
            do {
                let snapshot = try await Task.detached(priority: .userInitiated) { try workspace.snapshot() }.value
                try await PhotoPackageIO.write(snapshot, to: url, archive: workspace.services.archive, codec: ImageIOCodec())
                didSave(url, kind: .document, opened: opened)
            } catch {
                didFailSave(error)
            }
        }
    }

    /// Saving (Save, Save As, Flatten) makes `url` the window's file; exporting doesn't.
    func write(to url: URL, as format: ImageFormat, quality: Double, saving: Bool) {
        let (workspace, opened) = (model, documentURL)
        note = saving ? "Saving…" : "Exporting…"
        if saving { files.working = .saving }
        Task {
            do {
                let data = try await workspace.export(as: format, quality: quality, codec: ImageIOCodec())
                try data.write(to: url, options: .atomic)
                if saving {
                    didSave(url, kind: .image(format), opened: opened)
                } else {
                    note = "Exported \(url.lastPathComponent)"
                }
            } catch {
                if saving { return didFailSave(error) }
                note = nil
                problem = "\(url.lastPathComponent) couldn't be written. \(Self.reason(error))"
            }
        }
    }

    /// A save landed at `url`; a file opened meanwhile keeps its own name and URL.
    private func didSave(_ url: URL, kind: PhotoFileKind, opened: URL?) {
        if documentURL == opened {
            documentURL = url
            model.didSave(as: url.lastPathComponent, kind: kind)
            files.autosave?.didSave(model: model)
            files.saves += 1
        }
        files.saveFailed = false
        files.working = nil
        files.noteRecent(url)
        note = "Saved \(url.lastPathComponent)"
    }

    private func didFailSave(_ error: Error) {
        let reason = Self.reason(error)
        note = nil
        files.working = nil
        files.saveFailed = true
        problem = "The image couldn't be saved: \(reason.hasSuffix(".") ? String(reason.dropLast()) : reason)."
    }

    static func reason(_ error: Error) -> String {
        switch error {
        case let failure as ImageIOCodec.Failure: failure.description
        case let failure as ArchiveError: failure.message
        case RasterError.invalid(let message): "The image is not valid: \(message)."
        default: error.localizedDescription
        }
    }
}

/// The file area's state, alerts, dialogs and timers over the window.
struct PhotoFileArea: ViewModifier {
    let model: PhotoWorkspace
    let files: PhotoFileSession
    let perform: PhotoPerform
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .environment(\.photoSaveStatus, model.saveStatus(
                autosaved: files.autosave?.autosaved ?? false, saveFailed: files.saveFailed))
            .background { PhotoWindowEdited(model: model, files: files, perform: perform) }
            .overlay { PhotoFileWorkNote(work: files.working) }
            .focusedSceneValue(\.photoRecentFiles, files.recentFiles)
            .confirmationDialog(
                "Keep layers?",
                isPresented: Binding(get: { files.keepLayers != nil }, set: { if !$0 { files.keepLayers = nil } }),
                titleVisibility: .visible, presenting: files.keepLayers
            ) { format in
                Button("Save as Photo Document") { perform(.file(.saveDocument)) }.keyboardShortcut(.defaultAction)
                Button("Flatten into \(format.title)") { perform(.file(.flatten(format))) }
                Button("Cancel", role: .cancel) {}
            } message: { format in
                Text("A \(format.title) file keeps one flat layer. A Photo Document keeps every layer, mask and adjustment.")
            }
            // A clean image has nothing left unsaved, so "Not saved" goes.
            .onChange(of: model.isDirty) {
                if !model.isDirty { files.saveFailed = false }
            }
            .onChange(of: model.revision) { files.autosave?.noteEdit(at: Date.now.timeIntervalSince1970) }
            // Ticks every second with this revision's workspace; the next revision restarts it.
            .task(id: model.revision) {
                let autosave = files.startAutosave(model.services.recovery)
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    await autosave.tick(model: model, now: Date.now.timeIntervalSince1970, codec: ImageIOCodec())
                }
            }
            .task { await files.offerRecovery(model) }
            .task { if let url = PhotoOpenQueue.shared.windowAppeared(openWindow) { perform(.openFile(url)) } }
            // A clean close leaves nothing to recover; a dirty one asked first (Don't Save discards).
            .onDisappear { if !model.isDirty { files.autosave?.discard() } }
            .alert(
                files.recoveryOffer?.message ?? "",
                isPresented: Binding(get: { files.recoveryOffer != nil }, set: { if !$0 { files.recoveryOffer = nil } }),
                presenting: files.recoveryOffer
            ) { offer in
                Button("Restore") { perform(.file(.restore(offer))) }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("photo.recovery.restore")
                Button("Discard", role: .destructive) { perform(.file(.discardRecovery)) }
                    .accessibilityIdentifier("photo.recovery.discard")
            }
    }
}

/// `photo.file.saving` / `photo.file.opening`: a spinner and the note over the
/// window once `work` has run 100 ms (a quick save shows nothing); nothing otherwise.
struct PhotoFileWorkNote: View {
    let work: PhotoFileWork?
    @State private var shown: PhotoFileWork?

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .overlay {
                if let shown {
                    GlassPanel {
                        HStack(spacing: SuiteSpacing.s) {
                            ProgressView().controlSize(.small)
                            Text(shown.note).font(SuiteFont.body)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(shown.note)
                    .accessibilityIdentifier(shown.identifier)
                }
            }
            .task(id: work) {
                shown = nil
                guard let work else { return }
                try? await Task.sleep(for: .milliseconds(100))
                if !Task.isCancelled { shown = work }
            }
    }
}

/// The window's hook (PhotoWindowEditedView).
struct PhotoWindowEdited: NSViewRepresentable {
    let model: PhotoWorkspace
    let files: PhotoFileSession
    let perform: PhotoPerform

    func makeNSView(context: Context) -> PhotoWindowEditedView { PhotoWindowEditedView() }

    func updateNSView(_ view: PhotoWindowEditedView, context: Context) { view.update(model, files: files, perform: perform) }
}

/// An invisible view that keeps its window's edited dot on the image's dirty
/// state, puts its close guard in front of the window's delegate, and answers
/// the unsaved-changes prompt for its window.
final class PhotoWindowEditedView: NSView, PhotoUnsavedWindow {
    /// The visible Photo windows' hooks, front to back.
    static var shown: [PhotoWindowEditedView] {
        let views = all.allObjects
        return NSApp.orderedWindows.filter { $0.isVisible }.compactMap { window in views.first { $0.window === window } }
    }

    private static let all = NSHashTable<PhotoWindowEditedView>.weakObjects()
    private(set) var workspace: PhotoWorkspace?
    private(set) var files: PhotoFileSession?
    private(set) var send: PhotoPerform?
    private let closeGuard = PhotoWindowCloseGuard()

    var isDirty: Bool { workspace?.isDirty ?? false }
    var isEmpty: Bool { workspace?.canvas == nil }

    func update(_ workspace: PhotoWorkspace, files: PhotoFileSession, perform: @escaping PhotoPerform) {
        self.workspace = workspace
        self.files = files
        send = perform
        attach()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attach()
    }

    /// The edited dot, and the close guard in front of SwiftUI's delegate.
    private func attach() {
        guard let window else { return }
        Self.all.add(self)
        window.isDocumentEdited = isDirty
        guard window.delegate !== closeGuard else { return }
        closeGuard.original = window.delegate
        closeGuard.hook = self
        window.delegate = closeGuard
    }

    func prepareToQuit() async {
        guard let workspace, let autosave = files?.autosave else { return }
        await autosave.willQuit(model: workspace, codec: ImageIOCodec())
    }

    func ask() async -> PhotoUnsavedPrompt.Answer {
        guard let window, let message = workspace?.unsavedPromptMessage else { return .cancel }
        window.makeKeyAndOrderFront(nil)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = PhotoUnsavedPrompt.informativeText
        for choice in PhotoUnsavedPrompt.choices {
            alert.addButton(withTitle: choice.title).setAccessibilityIdentifier(choice.identifier)
        }
        let response = await alert.beginSheetModal(for: window)
        return PhotoUnsavedPrompt.answer(
            forButton: response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
    }

    /// Runs Save (maybe Keep layers? or the panel) and waits; true once it landed.
    func save() async -> Bool {
        guard let files, let send else { return false }
        let before = files.saves
        send(.save)
        while files.working != nil || files.keepLayers != nil {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return false }
        }
        return files.saves != before
    }

    func discardChanges() { files?.autosave?.discard() }
}

/// The window's delegate in front of SwiftUI's: asks before a dirty window
/// closes and passes every other delegate call to the original.
@MainActor final class PhotoWindowCloseGuard: NSObject, NSWindowDelegate {
    /// SwiftUI's delegate; AppKit calls `responds(to:)` on the main thread.
    nonisolated(unsafe) weak var original: (any NSWindowDelegate)?
    weak var hook: PhotoWindowEditedView?
    /// The prompt is up, or its answer is closing the window.
    private var asking = false, confirmed = false

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if asking { return false }
        guard !confirmed, let hook, PhotoUnsavedFlow.asksOnClose(hook) else {
            return original?.windowShouldClose?(sender) ?? true
        }
        asking = true
        Task {
            let closes = await PhotoUnsavedFlow.close(hook)
            asking = false
            guard closes else { return }
            confirmed = true
            sender.performClose(nil)
            confirmed = false
        }
        return false
    }

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || original?.responds(to: aSelector) == true
    }

    nonisolated override func forwardingTarget(for aSelector: Selector!) -> Any? {
        original?.responds(to: aSelector) == true ? original : super.forwardingTarget(for: aSelector)
    }
}

extension FocusedValues {
    /// The focused Photo window's Open Recent files, newest first.
    var photoRecentFiles: [URL]? {
        get { self[PhotoRecentFilesKey.self] }
        set { self[PhotoRecentFilesKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, as PhotoMenuKey.
private struct PhotoRecentFilesKey: FocusedValueKey {
    typealias Value = [URL]
}
