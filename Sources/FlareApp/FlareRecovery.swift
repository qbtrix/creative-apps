// FlareRecovery.swift: autosave, the recovery offer and the failed-save status on the window
// (docs/blueprints/flare/features/layers-files.md, LF-5; adopt-kernel-autosave AK-4). Autosave and the launch
// offer are the suite's `.autosaveRecovery` with the hooks FlareWorkspace gives (FlareRecovery+Kernel.swift): the
// window id, the file name, the unsaved mark, the dirty document's encoder and a restore that lands the bytes as one
// undo step. Quitting while dirty writes the same pair once more, at once, before the app exits
// (`writeRecoveryOnQuit`), so an edit made inside the autosave delay survives the quit. Its folder is `Recovery/`
// in Flare's folder under the suite root (`-SuiteSupportDir` moves it), none for a launch that ignores restored
// state (the journeys' `-ApplePersistenceIgnoreState`) unless it names its own store (the recovery journey's); only
// a launch that keeps state moves an earlier build's `Recovery.flare` into it, once. After a failed save the
// window's subtitle reads `model.saveStatus`, and the same "Not saved" shows in the error color at the window's
// bottom trailing corner (`flare.saveStatus`), its tooltip the failure.
import AppKit
import FlareModel
import SuiteModel
import SuiteUI
import SwiftUI

struct FlareRecovery: ViewModifier {
    let model: FlareWorkspace
    /// Opens a recovered copy's bytes through the window's Model.
    let restore: @MainActor (Data) throws -> Void

    func body(content: Content) -> some View {
        content
            .navigationSubtitle(model.saveStatus ?? "")
            .overlay(alignment: .bottomTrailing) {
                if let status = model.saveStatus {
                    // Its tooltip is why the save failed.
                    EditorSaveStatus(.notSaved, title: status, help: model.saveError ?? "", identifier: "flare.saveStatus")
                        .padding(SuiteSpacing.s)
                }
            }
            .autosaveRecovery(
                hooks, folder: Self.folder, delay: FlareWorkspace.autosaveDelay, edits: model.document.hashValue)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                // Synchronous: the process ends once this returns.
                guard let folder = Self.folder else { return }
                model.writeRecoveryOnQuit(to: folder, at: Date.now.timeIntervalSinceReferenceDate)
            }
    }

    /// What `.autosaveRecovery` reads from the Model.
    private var hooks: AutosaveHooks {
        let model = model
        let restore = restore
        return AutosaveHooks(
            window: model.recoveryWindow,
            documentName: { model.fileName },
            isDirty: { model.isDirty },
            encoder: { model.recoveryEncoder() },
            restore: { try restore($0) })
    }

    /// This launch's recovery folder, after an earlier build's copy moved into it (never under ignore-state). A
    /// static, so it runs once per process and a body pass builds nothing.
    private static let folder = FlareWorkspace.launchRecoveryFolder(
        arguments: ProcessInfo.processInfo.arguments, home: NSHomeDirectory(),
        ignoresState: UserDefaults.standard.bool(forKey: "ApplePersistenceIgnoreState"))
}
