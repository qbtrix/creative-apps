// HaloHistoryArea.swift (autosave-history HA-2): the History panel and the
// autosave hooks on Halo's window (packet
// docs/blueprints/halo/features/autosave-history.md). `historyScene(_:)`, one
// line in HaloWindow's hooks, hands the window's HaloHistoryShelf and its
// jump down the environment, and HaloHistoryOverlay, which HaloViewer lays over
// the viewer's bottom trailing corner (never over the status row or timeline,
// #5844), draws SuiteUI's HistoryPanel while the shelf says so, reading the
// Model's `historyListing` (the kernel `History.listing`) and sending a row's
// jump to the Model's `jumpHistory(to:)`; and `.autosaveRecovery` with the
// hooks the Model gives: the file name, the unsaved mark and HaloFiles' bytes,
// written to HaloRecoveryStore's folder for this launch (`<support>/Halo/Recovery/`,
// none for a journey launch or a test host without `-SuiteSupportDir`), and a
// Restore that hands the copy to the window's `restoreRecovered` (HA-7b).
// The shelf is the window's own presentation state, never the Model's; the
// History button by the transport (HaloHistoryControl in HaloControls.swift)
// toggles it (HA-3). Every jump goes through the window's `jumpHistory(_:)`
// once; the panel follows an undo or a jump because each window body hands it
// the Model's listing as it now is. No history logic lives here.
import HaloModel
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI

/// Whether the window shows its History panel: presentation state, not the Model's.
@MainActor @Observable final class HaloHistoryShelf {
    var shown: Bool

    init(shown: Bool = false) {
        self.shown = shown
    }
}

extension EnvironmentValues {
    /// The window's History shelf; nil outside a Halo window, where the History button is disabled.
    @Entry var haloHistoryShelf: HaloHistoryShelf?
    /// Where the History panel sends a row's jump: the window's `jumpHistory(_:)`.
    @Entry var haloHistoryJump: @MainActor (Int) -> Void = { _ in }
}

/// The History panel while the shelf says so, at the bottom trailing corner of
/// whatever it overlays: the viewer, so it never covers its own button, the
/// status row or the timeline (#5844, H-J13). It reads `model`'s listing and
/// shrinks to a short viewer rather than spill out of it.
struct HaloHistoryOverlay: View {
    let model: HaloProject
    @Environment(\.haloHistoryShelf) private var shelf
    @Environment(\.haloHistoryJump) private var jump

    var body: some View {
        if shelf?.shown == true {
            HistoryPanel(listing: model.historyListing, onJump: jump)
                .frame(maxWidth: SuiteSize.editorPanelWidth, maxHeight: SuiteSize.editorPanelWidth)
                .background(SuiteColor.panel, in: RoundedRectangle(cornerRadius: SuiteRadius.large))
                .overlay(RoundedRectangle(cornerRadius: SuiteRadius.large).stroke(SuiteColor.outline))
                .padding(SuiteSpacing.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
}

extension HaloWindow {
    #if DEBUG
    /// Jumps the panel sent to the Model; HaloHistoryAreaTests counts one per row press.
    // view-static: main-actor
    static var historyJumps = 0
    #endif

    /// The History panel and the autosave hooks over `content`.
    func historyScene(_ content: some View) -> some View {
        content.modifier(HaloHistoryArea(model: model, restore: restoreRecovered) { index in jumpHistory(index) })
    }

    /// Restore on the recovery offer: the copy's project in place of this one, named as the file open now.
    func restoreRecovered(_ data: Data) throws {
        try model.restoreRecovered(from: data, name: model.file.name)
    }

    /// A row click or Return in the panel: one jump on the Model, which the panel then follows
    /// as it follows an undo (each body hands it the listing as it now is).
    func jumpHistory(_ index: Int) {
        #if DEBUG
        Self.historyJumps += 1
        #endif
        _ = try? model.jumpHistory(to: index)
    }
}

/// The shelf, the jump and the autosave hooks over the window; HaloHistoryOverlay draws the panel from them.
struct HaloHistoryArea: ViewModifier {
    let model: HaloProject
    /// Puts a recovered copy's bytes in the window; the snapshots' host keeps no copies, so never calls it.
    var restore: @MainActor (Data) throws -> Void = { _ in }
    let onJump: @MainActor (Int) -> Void
    /// A shelf given from outside (the snapshots'), else the window's own.
    @Environment(\.haloHistoryShelf) private var given
    @State private var own = HaloHistoryShelf()

    func body(content: Content) -> some View {
        content
            .environment(\.haloHistoryShelf, given ?? own)
            .environment(\.haloHistoryJump, onJump)
            .autosaveRecovery(hooks, folder: Self.folder, delay: 2, edits: model.historyListing.hashValue)
    }

    /// Where this launch's window keeps its recovery copies; nil keeps none. The ignore-state default covers
    /// the launch flag and a test host's registered one, so hosted windows never write or offer real copies.
    private static let folder = HaloRecoveryStore.folder(
        arguments: ProcessInfo.processInfo.arguments, home: NSHomeDirectory(),
        ignoringState: UserDefaults.standard.bool(forKey: "ApplePersistenceIgnoreState"))

    /// What `.autosaveRecovery` reads from the Model.
    private var hooks: AutosaveHooks {
        let project = model, restore = self.restore
        return AutosaveHooks(
            window: "halo.main",
            documentName: { project.file.name },
            isDirty: { project.file.unsaved },
            encoder: {
                guard project.file.unsaved else { return nil }
                return { try project.recoveryBytes() }
            },
            restore: { data in try restore(data) })
    }
}
