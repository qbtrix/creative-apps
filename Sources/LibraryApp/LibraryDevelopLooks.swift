// LibraryDevelopLooks.swift (adjust-everywhere AJ-11): the Develop tab's
// LOOKS grid (SuiteUI's LookGrid over the catalog as its AdjustTarget) and
// BLACK & WHITE section (a checkbox, and the six colour weights while it is
// on: off, they would only sit there dimmed), plus the
// window's half that runs their commands. Each runs one catalog command
// (`look.apply`, `look.save`, `look.delete`, `adjust.black-and-white`) on the
// develop targets as one undo step; an apply or a B&W change then renders the
// loupe and redraws the changed thumbnails like any develop edit (the loupe's
// renderer appends the kinds, LiveDevelop.render). A weight drag's samples
// preview in the loupe as one coalesced step (`setGrayWeights`) that ends with
// the Develop tab's endEdit, like a slider. Values in, closures out.
import LibraryModel
import SuiteImaging
import SuiteKernel
import SuiteUI
import SwiftUI

extension LibraryMenu {
    /// What LOOKS and BLACK & WHITE call: one catalog command by id and params; nil outside a window.
    struct Adjust {
        var run: (@MainActor (String, JSONValue) -> Void)?
        /// One sample of a weight drag; the drag ends with the Develop tab's endEdit.
        var setWeights: (@MainActor (GrayWeights) -> Void)?
    }
}

extension EnvironmentValues {
    /// The window's `adjustControls`, read by the Develop tab; `run` is nil outside a window.
    @Entry var libraryAdjust = LibraryMenu.Adjust()
}

extension LibraryWindow {
    var adjustControls: LibraryMenu.Adjust {
        let run: @MainActor (String, JSONValue) -> Void = { (id: String, params: JSONValue) -> Void in
            let targets: Set<String> = model.developTargets
            guard (try? LibraryCatalog.catalog.run(id, params: params, on: &model)) != nil else { return }
            if id == "look.apply" || id.hasPrefix("adjust.") { developFinish(targets) }
        }
        let setWeights: @MainActor (GrayWeights) -> Void = { (weights: GrayWeights) -> Void in
            model.setGrayWeights(weights, coalesceKey: "develop-bw")
            developPreview()
        }
        let canEdit = model.developHelp == nil
        return LibraryMenu.Adjust(run: enabled(canEdit, run), setWeights: enabled(canEdit, setWeights))
    }
}

/// LOOKS: the built-in looks, then the saved ones; Save and Delete re-read the store.
struct DevelopLooksSection: View {
    let model: LibraryCatalog
    @Environment(\.libraryAdjust) private var adjust
    /// Bumped after a save or delete so the rows re-read the store.
    @State private var revision = 0

    var body: some View {
        let run = adjust.run
        InspectorSection("Looks") {
            LookGrid(
                rows: LookGridRows(model.looks), target: model,
                onApply: { (id: String) in run?("look.apply", .object(["id": .string(id)])) },
                onSave: { (name: String) in
                    run?("look.save", .object(["name": .string(name)]))
                    revision += 1
                },
                onDelete: { (id: String) in
                    run?("look.delete", .object(["id": .string(id)]))
                    revision += 1
                })
                .id(revision)
        }
    }
}

/// BLACK & WHITE: the checkbox turns the targets' B&W on (core's default mix) or off; each weight row moves one
/// colour's weight while it is on.
struct DevelopBlackAndWhiteSection: View {
    let model: LibraryCatalog
    /// The Develop tab's endEdit, which ends a weight drag's step.
    let endEdit: (@MainActor () -> Void)?
    @Environment(\.libraryAdjust) private var adjust

    static let colors: [(String, WritableKeyPath<GrayWeights, Double>)] = [
        ("Reds", \.red), ("Yellows", \.yellow), ("Greens", \.green), ("Cyans", \.cyan), ("Blues", \.blue),
        ("Magentas", \.magenta),
    ]

    var body: some View {
        let stored: GrayWeights? = Self.weights(model.kinds)
        let help: String = model.adjustHelp ?? DevelopInspector.unavailable
        let enabled = adjust.run != nil && model.adjustHelp == nil
        InspectorSection("Black & White") {
            InspectorRow("") {
                Toggle("Black & White", isOn: Binding(get: { stored != nil }, set: { on in
                    run(on ? .neutral : nil)
                }))
                .toggleStyle(.checkbox)
            }
            .disabled(!enabled)
            .help(enabled ? "" : help)
            .libraryControl(id: "library.develop.bw", enabled: enabled, help: help)
            if let stored {
                ForEach(Self.colors, id: \.0) { color in
                    weightRow(color.0, color.1, shown: stored, on: enabled)
                }
            }
        }
    }

    private func weightRow(
        _ title: String, _ key: WritableKeyPath<GrayWeights, Double>, shown: GrayWeights, on: Bool
    ) -> some View {
        let why = "Turn on Black & White to mix its colours."
        return InspectorSliderRow(
            title, value: shown[keyPath: key], in: GrayWeights.range, step: 1, unit: "%", decimals: 0,
            onChange: { (value: Double) in
                var next = shown
                next[keyPath: key] = value
                adjust.setWeights?(next)
            },
            onEnd: { endEdit?() })
            .disabled(!on)
            .help(on ? "" : why)
            .libraryControl(id: "library.develop.bw." + title.lowercased(), enabled: on, help: why)
    }

    /// `adjust.black-and-white` with `weights`; nil takes B&W off.
    private func run(_ weights: GrayWeights?) {
        guard let w = weights else {
            adjust.run?("adjust.black-and-white", .object([:]))
            return
        }
        let mix: [String: JSONValue] = [
            "red": .number(w.red), "yellow": .number(w.yellow), "green": .number(w.green),
            "cyan": .number(w.cyan), "blue": .number(w.blue), "magenta": .number(w.magenta),
        ]
        adjust.run?("adjust.black-and-white", .object(["weights": .object(mix)]))
    }

    /// The B&W weights `kinds` carries; nil without B&W.
    nonisolated static func weights(_ kinds: [ImagingKind]) -> GrayWeights? {
        for case .blackAndWhite(let w) in kinds { return w }
        return nil
    }
}
