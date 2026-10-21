// PhotoWindow+File.swift: the file area of a Photo window (photo-documents,
// PV-1): its intents, its route, its hook on the window, the services the
// window runs on, and open, Save, Save As and the writes they share. New
// Image, Open, Save and Save As route through PhotoWindow.perform to the
// helpers here; Keep layers?' choices and Clear Menu are FileIntents. Save
// goes where `model.saveAction` says: a document is written over its `.ora`
// (PhotoPackageIO, the snapshot taken off the main actor), a flat image over
// its file, a flat file whose image has layers asks "Keep layers?" (Save as
// Photo Document writes `<name>.ora` beside it, or in `-PhotoSaveTo`'s
// folder, and makes that the file; Flatten writes the flat file; an NSAlert
// sheet whose buttons carry `photo.file.keep-layers.*`, its words from
// PhotoKeepLayers), and a new
// or read-only image is Save As (the panel offers .ora, PNG and JPEG;
// `-PhotoSaveTo <folder>` writes `<name>.ora` there when the image needs a
// document, else `<name>.png`). A failed save shows "The image couldn't be
// saved: <reason>." and sets `files.saveFailed` until the image is clean.
// A save leaves no note (the save status says "Saved"); an export notes "Exported <name>".
// Open reads an `.ora` and decodes its PNGs off the main actor, then opens
// the snapshot; a bad document shows its ArchiveError message and the window
// keeps what it had. Flat files open through `openImage`, so Save knows
// their kind. Each successful open and save is noted in Open Recent and,
// through SuiteDocumentsBridge (file-flow PF-4), in the suite's shared
// recents: `.opened` or `.saved`, once each, with the file's suite type.
// `-PhotoOpenFile <path>` opens a file at launch; `-PhotoRecoveryDir
// <folder>` keeps autosaves there. PhotoFileSession is the file state the
// window and PhotoFileArea share. PhotoFileArea
// puts `model.saveStatus` in the environment for the window's
// subtitle and `photo.bar.saved`, keeps the window's edited dot (`isDocumentEdited`) on
// `model.isDirty`, and shows "Saving…" (`photo.file.saving`) or "Opening…"
// (`photo.file.opening`) over the window once `files.working` has run 100 ms.
// Autosave is SuiteUI's `.autosaveRecovery` (history-panel PH-6) on
// `model.services.recoveryFolder`: its hooks read the image's name and dirty
// state, copy the workspace on main and encode its `.ora` off it, and
// Restore decodes a copy off main (`PhotoWorkspace.recovered`) and installs
// it as `.restoreRecovered`. The folder is `-PhotoRecoveryDir`'s when given,
// none for a launch that ignores restored state (`-ApplePersistenceIgnoreState`),
// else Application Support/Photo. A save, a clean close and Don't Save
// remove the window's copy; Quit writes it once more while the image is
// dirty. D-10: PhotoWindowEditedView is the window's hook for Quit and
// Finder opens (PhotoApp.swift); its close guard
// asks PhotoUnsavedPrompt's alert before a dirty window closes.
import AppKit
import CoreRaster
import Observation
import PhotoModel
import SuiteModel
import SuiteShell
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
    /// Restore on the autosave's offer: the image `PhotoWorkspace.recovered` decoded.
    case restoreRecovered(PhotoWorkspace)
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
    /// This window's name in the recovery folder.
    let window = UUID().uuidString

    /// The folder this window autosaves to on `services`: `-PhotoRecoveryDir`'s
    /// when given (the services already keep it), none when the launch ignores
    /// restored state, else the services' own.
    nonisolated static func recoveryFolder(_ services: PhotoServices) -> RecoveryFolder? {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "PhotoRecoveryDir") != nil || !defaults.bool(forKey: "ApplePersistenceIgnoreState")
        else { return nil }
        return services.recoveryFolder
    }

    /// Removes this window's recovery copy: a save, a clean close or Don't Save.
    func discardRecovery(_ services: PhotoServices) {
        try? Self.recoveryFolder(services)?.discard(window: window)
    }

    /// Quit: writes this window's copy of `model` once more, off the main actor, while it is dirty.
    func writeRecovery(_ model: PhotoWorkspace) async {
        guard model.isDirty, model.canvas != nil, let folder = Self.recoveryFolder(model.services) else { return }
        let (encode, window, name) = (model.recoveryEncoder(codec: ImageIOCodec()), window, model.documentName)
        let now = Date.now.timeIntervalSinceReferenceDate
        _ = try? await Task.detached(priority: .userInitiated) {
            try folder.write(try encode(), window: window, name: name, at: now)
        }.value
    }

    /// The bridge opens and saves are noted through; nil uses the process's (tests inject one).
    @ObservationIgnored var bridge: SuiteDocumentsBridge?

    /// Photo's bridge on the live suite store (`-SuiteSupportDir` moves it), made on first use.
    static let suiteBridge: SuiteDocumentsBridge = {
        let arguments = ProcessInfo.processInfo.arguments
        let support = SuiteLocations.supportFolder(arguments: arguments, home: NSHomeDirectory())
        return SuiteDocumentsBridge(app: .photo, services: .live(support: support, app: .photo, arguments: arguments))
    }()

    /// Notes `url` in Open Recent: the system's list, Photo's own (an app with
    /// no declared document types may not get the system's), and the suite's
    /// shared recents as `event`, when the suite knows the file's type.
    func noteRecent(_ url: URL, _ event: RecentEvent) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        store(Array(([url] + recentFiles.filter { $0 != url }).prefix(10)))
        let bridge = self.bridge ?? Self.suiteBridge
        guard let type = bridge.registry.type(forExtension: url.pathExtension)?.id else { return }
        let path = url.path(percentEncoded: false)
        bridge.noted(SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .photo,
                                      type: type, displayName: url.lastPathComponent), event)
    }

    func clearRecent() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        store([])
    }

    private nonisolated static let recentKey = "PhotoRecentFiles"

    /// The saved list; Open Recent reads it with no window open.
    nonisolated static func storedRecent() -> [URL] {
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
        case .restoreRecovered(let restored):
            model.restoreRecovered(restored)
            documentURL = nil
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
            files.noteRecent(url, .opened)
            note = side.map { "Opened at \($0) px on the longest side (Photo opens up to \(PhotoWorkspace.maxOpenPixels / (1024 * 1024)) MP)" }
        } catch {
            problem = PhotoProblem("\(url.lastPathComponent) can't be opened.", Self.reason(error))
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
                files.noteRecent(url, .opened)
                note = nil
            } catch let error as ArchiveError {
                problem = PhotoProblem("\(name) can't be opened.", error.message)
            } catch {
                problem = PhotoProblem("\(name) can't be opened.", Self.reason(error))
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
                    model.endExport(.success([url.lastPathComponent]))
                    note = "Exported \(url.lastPathComponent)"
                }
            } catch {
                if saving { return didFailSave(error) }
                model.endExport(.failure(error))
                note = nil
                problem = PhotoProblem("\(url.lastPathComponent) couldn't be written.", Self.reason(error))
            }
        }
    }

    /// A save landed at `url`; a file opened meanwhile keeps its own name and URL.
    private func didSave(_ url: URL, kind: PhotoFileKind, opened: URL?) {
        if documentURL == opened {
            documentURL = url
            model.didSave(as: url.lastPathComponent, kind: kind)
            if !model.isDirty { files.discardRecovery(model.services) }
            files.saves += 1
        }
        files.saveFailed = false
        files.working = nil
        files.noteRecent(url, .saved)
        note = nil  // the save status `photo.bar.saved` says "Saved"
    }

    private func didFailSave(_ error: Error) {
        let reason = Self.reason(error)
        note = nil
        files.working = nil
        files.saveFailed = true
        problem = PhotoProblem("Not saved", "The image couldn't be saved: \(reason.hasSuffix(".") ? String(reason.dropLast()) : reason).")
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
            .environment(\.photoSaveStatus, model.saveStatus(autosaved: false, saveFailed: files.saveFailed))
            .background { PhotoWindowEdited(model: model, files: files, perform: perform) }
            .overlay {
                // A quick save shows nothing: the note waits 100 ms.
                if let work = files.working {
                    BusyNote(work.note, identifier: work.identifier, delay: .milliseconds(100))
                }
            }
            .focusedSceneValue(\.photoRecentFiles, files.recentFiles)
            // Keep layers? as a sheet on the window; Cancel (or no window) just closes it.
            .task(id: files.keepLayers) {
                guard let format = files.keepLayers else { return }
                guard let hook = await PhotoWindowEditedView.hook(for: files),
                      let choice = await hook.askToKeepLayers(format, message: model.keepLayersMessage(format: format))
                else {
                    files.keepLayers = nil
                    return
                }
                perform(.file(choice))
            }
            // A clean image has nothing left unsaved, so "Not saved" goes.
            .onChange(of: model.isDirty) {
                if !model.isDirty { files.saveFailed = false }
            }
            .autosaveRecovery(autosaveHooks, folder: PhotoFileSession.recoveryFolder(model.services),
                              delay: PhotoWorkspace.autosaveDelay, edits: model.revision)
            .task { if let url = PhotoOpenQueue.shared.windowAppeared(openWindow) { perform(.openFile(url)) } }
            // A clean close leaves nothing to recover; a dirty one asked first (Don't Save discards).
            .onDisappear { if !model.isDirty { files.discardRecovery(model.services) } }
    }

    /// The autosave's hooks: this render's workspace, copied on main by
    /// `encoder`; Restore decodes off main, then installs through `perform`.
    private var autosaveHooks: AutosaveHooks {
        let (model, perform) = (model, perform)
        return AutosaveHooks(
            window: files.window, documentName: { model.documentName }, isDirty: { model.isDirty },
            encoder: { model.isDirty && model.canvas != nil ? model.recoveryEncoder(codec: ImageIOCodec()) : nil },
            restore: { data in
                let restored = try await PhotoWorkspace.recovered(
                    from: data, name: nil, services: model.services, codec: ImageIOCodec())
                perform(.file(.restoreRecovered(restored)))
            })
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
/// the unsaved-changes prompt and "Keep layers?" for its window.
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
        guard let workspace, let files else { return }
        await files.writeRecovery(workspace)
    }

    /// "Keep layers?" as a sheet: Save as Photo Document (Return), Flatten
    /// into `format`, or nil for Cancel (Escape). An NSAlert, since SwiftUI drops
    /// an alert's button identifiers, so each keeps its `photo.file.keep-layers.*`.
    func askToKeepLayers(_ format: ImageFormat, message: String) async -> FileIntent? {
        guard let window else { return nil }
        let alert = NSAlert()
        alert.messageText = PhotoKeepLayers.title
        alert.informativeText = message
        for choice in PhotoKeepLayers.choices(format: format) {
            alert.addButton(withTitle: choice.title).setAccessibilityIdentifier(choice.identifier)
        }
        let response = await alert.beginSheetModal(for: window)
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        switch PhotoKeepLayers.answer(forButton: index, format: format) {
        case .saveDocument: return .saveDocument
        case .flatten(let flat): return .flatten(flat)
        case .cancel: return nil
        }
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

    func discardChanges() {
        guard let files, let workspace else { return }
        files.discardRecovery(workspace.services)
    }
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
