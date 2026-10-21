// HaloHistoryArea.swift (autosave-history HA-2): the History panel and the
// autosave hooks on Halo's window (packet
// docs/blueprints/halo/features/autosave-history.md). `historyScene(_:)`, one
// line in HaloWindow's hooks, puts SuiteUI's HistoryPanel over the window's
// bottom trailing corner while the HaloHistoryShelf says so, reading the
// Model's `historyListing` (the kernel `History.listing`) and sending a row's
// jump to the Model's `jumpHistory(to:)`; and `.autosaveRecovery` with the
// hooks the Model gives: the file name, the unsaved mark and HaloFiles' bytes.
// The shelf is the window's own presentation state, never the Model's; the
// History button by the transport (HaloHistoryControl in HaloControls.swift)
// toggles it. On HA-1's stubs a jump throws and does nothing, and the folder
// is nil, so autosave stays off until HA-7. No history logic lives here.
import HaloModel
import SuiteKernel
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
}

extension HaloWindow {
    /// The History panel and the autosave hooks over `content`.
    func historyScene(_ content: some View) -> some View {
        content.modifier(HaloHistoryArea(model: model) { index in _ = try? model.jumpHistory(to: index) })
    }
}

/// The panel over the window and the autosave hooks; it reads `model` and sends each jump to `onJump` once.
struct HaloHistoryArea: ViewModifier {
    let model: HaloProject
    let onJump: @MainActor (Int) -> Void
    /// A shelf given from outside (the snapshots'), else the window's own.
    @Environment(\.haloHistoryShelf) private var given
    @State private var own = HaloHistoryShelf()

    func body(content: Content) -> some View {
        let shelf = given ?? own
        content
            .overlay(alignment: .bottomTrailing) {
                if shelf.shown {
                    HistoryPanel(listing: model.historyListing, onJump: onJump)
                        .frame(width: SuiteSize.editorPanelWidth, height: SuiteSize.editorPanelWidth)
                        .background(SuiteColor.panel, in: RoundedRectangle(cornerRadius: SuiteRadius.large))
                        .overlay(RoundedRectangle(cornerRadius: SuiteRadius.large).stroke(SuiteColor.outline))
                        .padding(SuiteSpacing.m)
                }
            }
            .environment(\.haloHistoryShelf, shelf)
            .autosaveRecovery(hooks, folder: nil, delay: 2, edits: model.historyListing.hashValue)
    }

    /// What `.autosaveRecovery` reads from the Model.
    private var hooks: AutosaveHooks {
        let project = model
        return AutosaveHooks(
            window: "halo.main",
            documentName: { project.file.name },
            isDirty: { project.file.unsaved },
            encoder: {
                guard project.file.unsaved else { return nil }
                return { try project.recoveryBytes() }
            },
            restore: { _ in throw HaloNotBuilt("Restoring a recovered copy arrives with HA-5.") })
    }
}
