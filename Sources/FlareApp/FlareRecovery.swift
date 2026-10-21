// FlareRecovery.swift: autosave, the recovery offer and the failed-save status on the window
// (docs/blueprints/flare/features/layers-files.md, LF-5; adopt-kernel-autosave AK-4). Autosave and the launch
// offer are the suite's `.autosaveRecovery` with the hooks FlareWorkspace gives (FlareRecovery+Kernel.swift): the
// window id, the file name, the unsaved mark, the dirty document's encoder and a restore that lands the bytes as one
// undo step. Its folder is `Recovery/` in Flare's folder under the suite root (`-SuiteSupportDir` moves it), none
// for a launch that ignores restored state (the journeys' `-ApplePersistenceIgnoreState`) unless it names its own
// store (the recovery journey's); the first build after an
// earlier one moves that build's `Recovery.flare` there once. After a failed save the window's subtitle reads
// `model.saveStatus`, and the same "Not saved" shows in the error color at the window's bottom trailing corner
// (`flare.saveStatus`), its tooltip the failure.
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

    /// This launch's recovery folder, after the earlier build's copy moved under the root. A static, so it runs
    /// once per process and a body pass builds nothing.
    private static let folder: RecoveryFolder? = {
        let (arguments, home) = (ProcessInfo.processInfo.arguments, NSHomeDirectory())
        FlareWorkspace.moveLegacyRecovery(arguments: arguments, home: home)
        return FlareWorkspace.recoveryFolder(
            arguments: arguments, home: home,
            ignoresState: UserDefaults.standard.bool(forKey: "ApplePersistenceIgnoreState"))
    }()
}
