// FlareDocumentSheet.swift (document-setup DS-14): Flare's door to SuiteUI's shared NewDocumentSheet. File > New,
// the toolbar's New and the empty state present it on Flare's presets (SuiteCreating) and its Create sends
// `.file(.create)` from `NewDocumentSpec(setup)`, the router dismissing it once the document opens. File > Document
// Settings… presents it in `.settings` mode on the open scene's setup; Apply writes it through `apply` (the window's
// `applyDocumentSetup`), and the sheet stays up with the reason when the model refuses. The rules live in
// FlareDocumentSetup+Kernel.swift; this file only presents.
import FlareModel
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI

/// Which setup sheet the window shows: a new animation, or the open one's settings.
enum FlareSetupSheet: Hashable, Identifiable {
    case new, settings

    var id: Self { self }
}

struct FlareDocumentSheet: ViewModifier {
    @Binding var sheet: FlareSetupSheet?
    /// The open scene's setup and limits, read when Document Settings opens.
    let setup: DocumentSetup
    let limits: DocumentLimits
    let perform: @MainActor (FlareIntent) -> Void
    /// Applies a settings change; true when the model took it.
    let apply: @MainActor (DocumentSetup, BoxAnchor) -> Bool

    func body(content: Content) -> some View {
        content.sheet(item: $sheet) { which in
            switch which {
            case .new:
                NewDocumentSheet(
                    .new(presets: SuiteCreating.presets[.flare] ?? [], clipboard: nil), setup: DocumentSetup(.hd1080),
                    limits: FlareWorkspace.newDocumentLimits,
                    onDone: { setup, _ in perform(.file(NewDocumentSpec(setup).intent)) }, onCancel: { sheet = nil })
            case .settings:
                NewDocumentSheet(
                    .settings, setup: setup, limits: limits,
                    onDone: { if apply($0, $1) { sheet = nil } }, onCancel: { sheet = nil })
            }
        }
    }
}
