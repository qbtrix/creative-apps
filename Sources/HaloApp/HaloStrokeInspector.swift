// HaloStrokeInspector.swift (stroke-style HK-2, HK-3): the STROKE slot of
// Halo's layer inspector, under FILL, shown only while a shape layer is
// selected (`shows`; text, solids and nulls take no stroke). It is SuiteUI's
// StrokeEditor on the selection's kernel stroke (`selectedStroke`), with the
// trim rows (Halo trims paths), each gesture one StrokeIntent sent to
// `runStroke`, which the window hands to `HaloProject.runStroke`. While
// `strokeHelp` says why (the HK-1 stubs until HK-6) every row is off with
// that reason as its tooltip and as the editor's note. Dash and trim draw
// once HK-5 renders them, so no dash help is passed. Under the editor each
// trim key the Model lists (`HaloProject.trimKeys`) gets a row with its
// stopwatch and key diamond, identified `halo.inspector.key.<trim>` the way
// TRANSFORM's are; a click goes to `toggleKey` (diamond true for the
// diamond), which the project's init maps through `trimKeyCommand` to
// `perform`, and a key with a reason is off with it as its tooltip. The
// rows sit under the editor until StrokeEditor offers a per-row accessory
// slot (needs-ui). Its inputs are values, so a snapshot can show any stroke;
// `init(model:)` reads them from the project. Values in, intents out.
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct HaloStrokeInspector: View {
    /// The selected shape layer's stroke; nil shows Add Stroke alone.
    let stroke: VectorStroke?
    /// Why the stroke commands can't run; nil while they can.
    let help: String?
    /// The trim rows' keys, in row order; empty without a stroked shape layer.
    var trimKeys: [HaloTrimKey] = []
    /// A trim key's click: the diamond when `diamond`, else the stopwatch.
    var toggleKey: @MainActor (HaloTrimKey, _ diamond: Bool) -> Void = { _, _ in }
    var runStroke: @MainActor (StrokeIntent) -> Void = { _ in }

    /// Whether STROKE shows for a layer of `kind`: shape layers only.
    nonisolated static func shows(_ kind: HaloLayerKind?) -> Bool { kind == .shape }

    /// The stopwatch's identifier for `key`; the diamond reads `KeyframeButton.diamondID` of it.
    nonisolated static func keyID(_ key: HaloTrimKey) -> String { "halo.inspector.key.\(key.raw)" }

    /// One click on `key`'s diamond (`diamond`) or stopwatch; nothing while it has a reason.
    func key(_ key: HaloTrimKey, diamond: Bool) {
        guard key.help == nil else { return }
        toggleKey(key, diamond)
    }

    var body: some View {
        InspectorSection("Stroke") {
            StrokeEditor(stroke: stroke, help: help, dashHelp: nil) { runStroke($0) }
            ForEach(trimKeys) { trim in
                InspectorRow(trim.title) { keyButton(trim) }
            }
        }
    }

    /// `trim`'s stopwatch and diamond. KeyframeButton sets both identifiers
    /// itself; here they are only listed, the diamond while shown.
    private func keyButton(_ trim: HaloTrimKey) -> some View {
        let id = Self.keyID(trim)
        let state = HaloPropertyRowView.keyState(trim.keyState)
        return KeyframeButton(
            trim.title, id: id, state: state, unavailableHelp: trim.help,
            onToggle: { key(trim, diamond: false) },
            onKey: { key(trim, diamond: true) })
            .disabled(trim.help != nil)
            .haloControl(id: id, enabled: trim.help == nil, help: trim.help, identifies: false)
            .haloControl(
                id: state.diamond == nil ? nil : KeyframeButton.diamondID(id), enabled: trim.help == nil,
                help: trim.help, identifies: false)
    }
}

extension HaloStrokeInspector {
    /// STROKE for the project's selected layer; a trim key's click goes to `perform` as its command.
    init(
        model: HaloProject, perform: @escaping @MainActor (HaloCommand) -> Void = { _ in },
        runStroke: @escaping @MainActor (StrokeIntent) -> Void
    ) {
        self.init(
            stroke: model.selectedStroke, help: model.strokeHelp, trimKeys: model.trimKeys,
            toggleKey: { trim, diamond in
                if let command = HaloProject.trimKeyCommand(trim, diamond: diamond) { perform(command) }
            },
            runStroke: runStroke)
    }
}
