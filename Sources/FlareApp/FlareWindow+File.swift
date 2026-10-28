// FlareWindow+File.swift: the router's file area (FlareWindow+Router.swift).
// New presents the shared New Document sheet (FlareDocumentSheet.swift); its Create
// (`.create`) makes the document from the sheet's NewDocumentSpec and
// dismisses it; a spec with a problem is refused (Create's help says why).
// Open and Open Recent read the file's bytes off the main actor, show the
// open's progress (`beginOpen`), decode it off the main actor too and land it
// through `finishOpen`; a file that can't be read or
// decoded keeps the open document and says why in `loadState`. Save writes
// `saveData()`'s bytes atomically off the main actor to `-FlareSaveTo`'s folder
// (as "<title>.flare"), else the file the document was opened from or last
// saved to, else where the save panel says; Save As always asks. A write that
// fails says why in `saveError`. The panels, the alerts and the dirty dot are
// FlareFilePanels' (FlareFilePanels.swift). Close asks to save a dirty document.
// Open Sample opens the named fixture document (FlareFixtures, as `-FlareSample`
// does) through `finishOpen`, clean and with no undo history; Keyed Ball is
// FlareWindow's menu door. Each open and save is noted in the suite's recents
// through the documents bridge, the one list Open Recent reads (#5126),
// and Clear Menu and the file-flow commands' requests go to the bridge (FL-4).
// A Lottie JSON (`FlareWorkspace.opensAsLottie`, lottie-open LO-4) opens through
// FlareLottieOpen off the main actor and lands through `finishLottieOpen`:
// untitled, with the import note above the stage (FlareImportNoteAdapter.swift); a
// refusal shows the open alert with the reader's reason. The JSON is never noted
// in the recents (LO-5): it is the source, not the document, and the suite's
// recents hold only .flare files; the first Save notes the new .flare.
import AppKit
import FlareCore
import FlareModel
import SuiteModel
import SuiteShell

extension FlareWindow {
    /// Acts on a file intent.
    func performFile(_ intent: FlareIntent.File) {
        switch intent {
        case .new: presented = .new
        case .open: if let url = FlareFileDialogs.chooseFile() { open(url) }
        case .openRecent(let path): open(URL(fileURLWithPath: path))
        case .clearRecent:
            try? model.clearRecent()
            drainFileRequests()
        case .save: Task { await save(asking: false) }
        case .saveAs: Task { await save(asking: true) }
        case .close: Task { await close() }
        case .openSample(let name): openSample(name)
        case .create:
            guard let spec = NewDocumentSpec(intent) else { return }
            model.newDocument(spec)
            if spec.problem == nil { presented = nil }
        }
    }

    /// Why a file intent can't act now; nil when it can.
    func fileHelp(_ intent: FlareIntent.File) -> String? {
        switch intent {
        case .new, .open, .openRecent, .close: nil
        case .clearRecent: Self.bridge.recents(for: .flare).isEmpty ? "No Recent Files" : nil
        case .save, .saveAs: model.document == nil ? "Open or create an animation first." : nil
        case .openSample(let name): FlareFixtures.named(name) == nil ? "No sample called \(name)." : nil
        case .create: createHelp(intent)
        }
    }

    /// Why Create can't make this spec's document; nil when it can.
    private func createHelp(_ intent: FlareIntent.File) -> String? {
        guard let spec = NewDocumentSpec(intent) else { return "Pick a valid background color." }
        return spec.problem
    }

    /// Opens the fixture called `name` under its menu title; an unknown name does nothing.
    func openSample(_ name: String) {
        guard let document = FlareFixtures.named(name) else { return }
        model.finishOpen(.success(document), named: name.prefix(1).uppercased() + name.dropFirst())
    }

    /// Reads, decodes and opens `url`; a failure keeps the open document.
    func open(_ url: URL) {
        if FlareWorkspace.opensAsLottie(url.path) { return openLottie(url) }
        let name = url.lastPathComponent
        model.beginOpen()
        Task {
            let read = await Task.detached(priority: .userInitiated) { () -> Result<Data, FormatError> in
                do {
                    return .success(try Data(contentsOf: url))
                } catch {
                    return .failure(.invalid(error.localizedDescription))
                }
            }.value
            let result: Result<FlareCore.Document, FormatError>
            switch read {
            case .success(let data):
                result = await Task.detached(priority: .userInitiated) { FlareWorkspace.decodeFile(data) }.value
            case .failure(let error):
                result = .failure(error)
            }
            model.finishOpen(result, named: name)
            if case .success = result {
                model.noteRecent(url.path)
                noteSuite(url, .opened)
            }
        }
    }

    /// Reads `url` and opens it as a Lottie off the main actor; a failure keeps the open document.
    func openLottie(_ url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        model.beginOpen()
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                () -> Result<(FlareDocument, [String]), FlareOpenError> in
                let data: Data
                do {
                    data = try Data(contentsOf: url)
                } catch {
                    return .failure(.damaged(error.localizedDescription))
                }
                return Result { () throws(FlareOpenError) in try FlareLottieOpen.open(data: data, name: name) }
            }.value
            model.finishLottieOpen(result)
        }
    }

    /// Writes the document; true once it is on disk. `asking` always shows the panel.
    @discardableResult
    func save(asking: Bool) async -> Bool {
        model.dismissFileError()  // the same failure twice shows its alert twice
        guard let save = model.saveData() else { return false }
        let name = "\(model.title).flare"
        let known = asking ? nil : saveURL
        guard let url = known ?? FlareFileDialogs.chooseSaveURL(named: name) else { return false }
        let failure = await Task.detached(priority: .userInitiated) { () -> String? in
            do {
                try save.data.write(to: url, options: .atomic)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value
        if let failure {
            model.saveFailed(failure)
            return false
        }
        model.didSave(save, named: url.lastPathComponent)
        model.noteRecent(url.path)
        noteSuite(url, .saved)
        return true
    }

    #if DEBUG
    /// A test's bridge in place of FlareShell's (FlareFileFlowLiveTests).
    @MainActor static var bridgeOverride: SuiteDocumentsBridge?
    #endif

    /// The documents bridge the window notes opens and saves in.
    @MainActor static var bridge: SuiteDocumentsBridge {
        #if DEBUG
        if let bridgeOverride { return bridgeOverride }
        #endif
        return FlareShell.bridge
    }

    /// Notes `url` in the suite's recents.
    func noteSuite(_ url: URL, _ event: RecentEvent) {
        if let ref = FlareWorkspace.suiteRef(url.path) { Self.bridge.noted(ref, event) }
    }

    /// Does what the file-flow commands left for the window.
    func drainFileRequests() {
        for request in model.takeFileRequests() {
            switch request {
            case .open(let path): open(URL(fileURLWithPath: path))
            case .handOff(let path, let app): Task { await Self.bridge.handOff([.handOff(path: path, app: app)]) }
            case .clearRecent: Task { await Self.bridge.clear(app: .flare) }
            case .forget: continue
            }
        }
    }

    /// Where Save writes without asking: `-FlareSaveTo`'s folder, else the
    /// file this document was opened from or last saved to (`filePath`,
    /// while it carries the document's name); nil asks.
    private var saveURL: URL? {
        if let folder = launch.saveFolder {
            return URL(fileURLWithPath: folder, isDirectory: true).appending(path: "\(model.title).flare")
        }
        guard let path = model.filePath, let name = model.fileName,
            URL(fileURLWithPath: path).lastPathComponent == name
        else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Closes the window, first asking to save a dirty document.
    func close() async {
        let window = NSApp.keyWindow
        if model.document != nil, model.isDirty {
            switch await FlareFileDialogs.askToSave(model.title, in: window) {
            case .cancel: return
            case .save: guard await save(asking: false) else { return }
            case .discard: break
            }
        }
        window?.close()
    }
}
