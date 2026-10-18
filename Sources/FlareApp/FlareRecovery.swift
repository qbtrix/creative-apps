// FlareRecovery.swift: autosave, the recovery offer and the failed-save status on the window
// (docs/blueprints/flare/features/layers-files.md, LF-5). The modifier owns the window's FlareAutosave: each
// document change notes an edit, and while the document is dirty a task waits out `autosaveDelay` and ticks,
// so the recovery file is written off the main actor once per edit; it restarts on the next edit or when the
// document turns clean, so a save never leaves a stale write behind. A clean document (a save, or another
// file opened) removes the file; quitting writes it once more while dirty. On launch the recovery file is read
// off the main thread and, when there is one, offered in a system alert, "Restore the unsaved animation from
// <time>?": Restore lands it through `restore` (FlareWorkspace.restoreRecovery) and keeps the file until the
// next save, so a second crash still recovers it; Discard removes it. The file is `-FlareRecoveryFile <path>`
// when given, none for a launch that ignores restored state (the journeys' `-ApplePersistenceIgnoreState`),
// else Application Support/Flare/Recovery.flare. After a failed save the window's subtitle reads
// `model.saveStatus`, and the same "Not saved" shows in the error color at the window's bottom trailing
// corner (`flare.saveStatus`), its tooltip the failure.
import AppKit
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI

struct FlareRecovery: ViewModifier {
    let model: FlareWorkspace
    let restore: @MainActor (FlareCore.Document) -> Void
    /// One per process: every window writes the one recovery file. A static, so a body pass builds nothing.
    @State private var autosave = FlareRecovery.shared
    @State private var offer: RecoveryOffer?

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
            .onChange(of: model.document) { autosave?.noteEdit(at: Self.now) }
            .onChange(of: model.isDirty) { _, dirty in if !dirty { autosave?.didSave() } }
            .task(id: AutosaveKey(document: model.document, dirty: model.isDirty)) {
                guard let autosave, model.isDirty else { return }
                try? await Task.sleep(for: .seconds(FlareWorkspace.autosaveDelay + 0.5))
                guard !Task.isCancelled else { return }
                await autosave.tick(model: model, now: Self.now)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                guard let autosave else { return }
                let model = model
                Task { await autosave.willQuit(model: model) }
            }
            .task {
                guard let autosave else { return }
                offer = await autosave.launch()
            }
            .alert(
                offer?.message ?? "",
                isPresented: Binding(get: { offer != nil }, set: { if !$0 { offer = nil } })
            ) {
                Button("Restore") {
                    if let offer { restore(offer.document) }
                    offer = nil
                }
                .accessibilityIdentifier("flare.recovery.restore")
                Button("Discard", role: .destructive) {
                    autosave?.discard()
                    offer = nil
                }
                .accessibilityIdentifier("flare.recovery.discard")
            }
    }

    /// Seconds on the wall clock; FlareAutosave only compares them.
    private static var now: Double { Date.now.timeIntervalSinceReferenceDate }

    private static let shared = makeAutosave()

    /// The autosave for this launch's recovery file; nil when the launch keeps none.
    private static func makeAutosave() -> FlareAutosave? {
        let defaults = UserDefaults.standard
        if let path = defaults.string(forKey: "FlareRecoveryFile"), !path.isEmpty {
            return FlareAutosave(recovery: RecoveryFile(url: URL(fileURLWithPath: path)))
        }
        guard !defaults.bool(forKey: "ApplePersistenceIgnoreState"),
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        return FlareAutosave(recovery: RecoveryFile(url: support.appending(path: "Flare/Recovery.flare")))
    }
}

/// What restarts the autosave wait: an edit, or the document turning clean or dirty.
private struct AutosaveKey: Equatable {
    let document: FlareCore.Document?
    let dirty: Bool
}
