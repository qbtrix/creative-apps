// FlareWindow+File.swift: the router's file area (FlareWindow+Router.swift).
// New presents the New Animation sheet (FlareNewSheet.swift); its Create
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
// FlareWindow's menu door.
import AppKit
import FlareCore
import FlareModel

extension FlareWindow {
    /// Acts on a file intent.
    func performFile(_ intent: FlareIntent.File) {
        switch intent {
        case .new: presented = .newAnimation
        case .open: if let url = FlareFileDialogs.chooseFile() { open(url) }
        case .openRecent(let path): open(URL(fileURLWithPath: path))
        case .clearRecent: model.clearRecent()
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
        case .clearRecent: model.recent.isEmpty ? "No recent animations." : nil
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
            if case .success = result { model.noteRecent(url.path) }
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
        return true
    }

    /// Where Save writes without asking: `-FlareSaveTo`'s folder, else the
    /// file this document was opened from or last saved to (the head of
    /// Open Recent while it carries the document's name); nil asks.
    private var saveURL: URL? {
        if let folder = launch.saveFolder {
            return URL(fileURLWithPath: folder, isDirectory: true).appending(path: "\(model.title).flare")
        }
        guard let path = model.recent.first, let name = model.fileName,
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
