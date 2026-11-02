// AnchorRows.swift (anchor-parenting AN-5): X, Y, the nine-point picker and
// Parent for one layer; each edit sends one command. No layer: disabled, says why.
import SuiteKernel
import SwiftUI

/// One command the anchor rows ask for: its catalog id and params.
public struct AnchorCommand: Equatable, Sendable {
    public let id: String
    public let params: JSONValue
}

/// X, Y, the nine-point picker and the Parent menu for one layer.
public struct AnchorRows: View {
    private let layer: String?, anchor: Point, box: Rect?, parent: String?, help: String?
    private let parents: [InspectorOption<String?>]
    private let onCommand: @MainActor (AnchorCommand) -> Void
    /// The anchor as a scrub or typing has it, sent once when the edit ends.
    @State private var draft: Point?

    /// `anchor` and `box` are in the layer's space; `parents` comes from `parentOptions(of:in:)`.
    public init(layer: String?, anchor: Point, box: Rect?, parent: String?, parents: [InspectorOption<String?>],
                help: String? = nil, onCommand: @escaping @MainActor (AnchorCommand) -> Void) {
        (self.layer, self.anchor, self.box, self.parent) = (layer, anchor, box, parent)
        (self.parents, self.help, self.onCommand) = (parents, help, onCommand)
    }

    public var body: some View {
        let reason = layer == nil ? Self.noLayer : help, shown = draft ?? anchor
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            InspectorRow("X") {
                ScrubField("Anchor X", value: shown.x, in: Self.range, decimals: 0,
                           onChange: { draft = Point(x: $0, y: shown.y) }, onEnd: commit)
                    .suiteControl(id: "suite.anchor.x", enabled: reason == nil, reason: reason)
            }
            InspectorRow("Y") {
                ScrubField("Anchor Y", value: shown.y, in: Self.range, decimals: 0,
                           onChange: { draft = Point(x: shown.x, y: $0) }, onEnd: commit)
                    .suiteControl(id: "suite.anchor.y", enabled: reason == nil, reason: reason)
            }
            Text("Anchor Point").font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.secondaryText).accessibilityHidden(true)
            PresetGrid(options: Self.pointOptions, selected: box.flatMap { Self.point(of: anchor, in: $0) }, columns: 3) { at in
                if let layer { onCommand(Self.command(at: at, layer: layer)) }
            }
            InspectorPickerRow("Parent", options: parents, selection: parent) { choice in
                if let layer { onCommand(Self.command(parent: choice, layer: layer)) }
            }
            .suiteControl(id: "suite.anchor.parent", enabled: reason == nil, reason: reason)
        }
        .disabled(reason != nil)
        .help(reason ?? "")
    }

    /// An X or Y edit ends: one `{x, y}` command for the draft, if it moved.
    private func commit() {
        defer { draft = nil }
        guard let layer, let draft, draft.x != anchor.x || draft.y != anchor.y else { return }
        onCommand(Self.command(x: draft.x, y: draft.y, layer: layer))
    }
    nonisolated static let noLayer = "Select a layer to set its anchor and parent."
    nonisolated static let range: ClosedRange<Double> = -100_000...100_000

    /// The nine points, top left to bottom right, titled ("Bottom Right") and `suite.anchor.at-<point>`.
    public nonisolated static let pointOptions = BoxAnchor.allCases.map { point in
        let title = point.rawValue.reduce(into: "") { words, c in words += words.isEmpty ? c.uppercased() : c.isUppercase ? " \(c)" : "\(c)" }
        return InspectorOption(id: point, title: title, identifier: "suite.anchor.at-\(point.rawValue)")
    }

    /// The nine point `anchor` sits on in `box`, nil when it's on none.
    nonisolated static func point(of anchor: Point, in box: Rect) -> BoxAnchor? {
        BoxAnchor.allCases.first { at in
            let p = Placement.anchorPoint(at: at, in: box)
            return abs(p.x - anchor.x) < 1e-6 && abs(p.y - anchor.y) < 1e-6
        }
    }
    public nonisolated static func command(at point: BoxAnchor, layer: String) -> AnchorCommand {
        AnchorCommand(id: "transform.set-anchor", params: .object(["id": .string(layer), "at": .string(point.rawValue)]))
    }
    public nonisolated static func command(x: Double, y: Double, layer: String) -> AnchorCommand {
        AnchorCommand(id: "transform.set-anchor", params: .object(["id": .string(layer), "x": .number(x), "y": .number(y)]))
    }
    /// `layer.set-parent` to `parent`, or clearing it when nil.
    public nonisolated static func command(parent: String?, layer: String) -> AnchorCommand {
        AnchorCommand(id: "layer.set-parent", params: .object(["id": .string(layer), "parent": parent.map(JSONValue.string) ?? .null]))
    }
    /// The Parent menu for `id`: None, then each layer front to back except `id` and every layer that follows it.
    public nonisolated static func parentOptions<P: LayerPayload>(of id: String, in tree: LayerTree<P>) -> [InspectorOption<String?>] {
        let others = tree.frontToBack.filter { $0 != id && !tree.follows($0, id) }.compactMap { other in
            tree.node(other).map { InspectorOption<String?>(id: other, title: $0.name, identifier: "suite.anchor.parent.\(other)") }
        }
        return [InspectorOption(id: nil, title: "None", identifier: "suite.anchor.parent.none")] + others
    }
}
