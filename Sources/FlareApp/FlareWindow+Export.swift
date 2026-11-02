// FlareWindow+Export.swift: the router's export area (FlareWindow+Router.swift).
// Export… opens the kernel's run through the Model (`openExport`); the sheet
// (FlareExportSheetAdapter.swift) sends its edits back here as intents. Export
// starts the run (`startExport`, refused while `exportProblem` names a reason),
// then one task finds the folder (`-FlareExportTo`, else the folder panel),
// runs the exporter off the main actor with its progress streamed back to the
// Model, and writes the files off the main actor too. The writer never
// overwrites and is all or nothing: a name already in the folder refuses the
// whole run (`ExportWriteRefusal.alreadyThere`) before a byte is written, and a
// failed write removes the files it wrote. Cancel cancels the task, which
// leaves the run idle with nothing written. The rasterizer is FakeRasterizer
// on the fakes and StageRasterizer otherwise. Reveal in Finder selects the
// first file written. MP4 and GIF (export-pack FV-2) stream the Model's frame
// plan into the Model's `exportVideoFileName` through `writeVideo` on shell-media's
// writers (FakeMedia on the fakes), which refuse a taken name (read back as
// `alreadyThere` by `videoWriteError`) and delete a cancelled partial file.
import AppKit
import FlareModel
import SuiteModel
import SuiteShell

extension FlareWindow {
    /// Acts on an export intent.
    func performExport(_ intent: FlareIntent.Export) {
        switch intent {
        case .showSheet: _ = model.openExport()
        case .setFormat(let format): model.setExportFormat(format)
        case .setFrames(let from, let to): if from <= to { model.setExportFrames(from...to) }
        case .setStep(let step): model.setExportStep(step)
        case .setScale(let scale): model.setExportScale(scale)
        case .setTransparent(let on): model.setExportTransparent(on)
        case .setSize(let size): model.setExportSize(size)
        case .setFrameRate(let fps): model.setExportFrameRate(fps)
        case .setLoop(let on): model.setExportLoop(on)
        case .start: startExport()
        case .cancel:
            if case .running = model.exportState { exportTask?.cancel() } else { model.dismissExport() }
        case .dismiss: model.dismissExport()
        case .tryAgain: model.retryExport()
        case .reveal: if let exportedFile { NSWorkspace.shared.activateFileViewerSelecting([exportedFile]) }
        }
    }

    /// Why an export intent can't act now; nil when it can.
    func exportHelp(_ intent: FlareIntent.Export) -> String? {
        switch intent {
        case .showSheet: model.document == nil ? model.exportProblem : nil
        case .start: model.exportProblem
        case .reveal: if case .finished = model.exportState, exportedFile != nil { nil } else { "Export first." }
        default: nil
        }
    }

    /// Starts the run, then exports and writes on one cancellable task.
    private func startExport() {
        guard let document = model.document, model.startExport(), let options = model.exportingOptions else { return }
        let exporter = model.services.export
        let rasterizer: any FrameRasterizing = model.services.isPreview ? FakeRasterizer() : StageRasterizer()
        let named = launch.exportFolder
        let media: any MediaEncoding = model.services.isPreview ? FakeMedia() : LiveMedia()
        exportedFile = nil
        exportTask = Task {
            let (fractions, sink) = AsyncStream.makeStream(of: Double.self)
            let progress = Task { for await fraction in fractions { model.exportProgressed(fraction) } }
            defer { sink.finish(); progress.cancel() }
            do {
                guard let folder = named.map({ URL(fileURLWithPath: $0) }) ?? FlareFileDialogs.chooseFolder() else {
                    throw CancellationError()
                }
                let names: [String]
                if options.format.writesVideo {
                    let plan = try model.exportVideoPlan()
                    guard let name = model.exportVideoFileName else { throw CancellationError() }
                    do {
                        _ = try await exporter.writeVideo(
                            document, sceneID: options.sceneID, plan: plan, to: folder.appending(path: name).path,
                            media: media, rasterizer: rasterizer
                        ) { sink.yield($0) }
                    } catch {
                        throw FlareWorkspace.videoWriteError(error, name: name, folder: folder.lastPathComponent)
                    }
                    names = [name]
                } else {
                    let result = try await exporter.export(document, options: options, rasterizer: rasterizer) { sink.yield($0) }
                    try Task.checkCancellation()
                    names = try await Task.detached(priority: .userInitiated) {
                        try Self.write(result.files, into: folder)
                    }.value
                }
                exportedFile = names.first.map { folder.appending(path: $0) }
                model.endExport(.success(names))
            } catch {
                model.endExport(.failure(error))
            }
        }
    }

    /// Writes every file into `folder` or none: refuses when any name is already there, and removes what it wrote
    /// when a write fails. Returns the names written, in order.
    nonisolated static func write(_ files: [ExportFile], into folder: URL) throws -> [String] {
        let manager = FileManager.default
        if let taken = files.first(where: { manager.fileExists(atPath: folder.appending(path: $0.name).path) }) {
            throw ExportWriteRefusal.alreadyThere(name: taken.name, folder: folder.lastPathComponent)
        }
        var written: [String] = []
        for file in files {
            do {
                try file.data.write(to: folder.appending(path: file.name), options: .atomic)
                written.append(file.name)
            } catch {
                for name in written { try? manager.removeItem(at: folder.appending(path: name)) }
                throw ExportWriteRefusal.cantWrite(folder: folder.lastPathComponent)
            }
        }
        return written
    }
}
