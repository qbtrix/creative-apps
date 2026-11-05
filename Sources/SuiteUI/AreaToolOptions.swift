// AreaToolOptions.swift (area-selection AR-7): the area tools' options bar: shape and mode chips, Feather (0...250 px)
// and, for the wand, Tolerance (0...255), Contiguous and All Layers. Each control names the `AreaSelectCommands`
// command it feeds (`AreaControl.command`). While Shift or Option is held the mode chip shows the keys' mode, as a drag
// uses it. Feather and Tolerance are whole-number bars; the bar holds the value being dragged and sends it once, when
// the drag, key step or typed value ends, so the host makes one change (one undo step) and reruns no body per sample.
// The view keeps only the held keys and that value; the host owns the options and gets each change with its control.
// Identifiers: `suite.area.tool-<shape>`, `suite.area.mode-<mode>` and `suite.area.<control>`.
import SuiteKernel
import SwiftUI

/// The five area selection tools, each run by its shape command.
public enum AreaTool: String, CaseIterable, Hashable, Sendable {
    case rect, ellipse, lasso, polygon, wand
    /// The command a drag or click with the tool runs.
    public var command: String { "select.\(rawValue)" }
    public var title: String { self == .rect ? "Rectangle" : rawValue.capitalized }
}

/// What the area tools are set to.
public struct AreaOptions: Hashable, Sendable {
    public var tool: AreaTool, mode: AreaCombine, feather: Double, tolerance: Double, contiguous: Bool, allLayers: Bool

    public init(tool: AreaTool = .rect, mode: AreaCombine = .replace, feather: Double = 0, tolerance: Double = 32,
                contiguous: Bool = true, allLayers: Bool = false) {
        (self.tool, self.mode, self.feather, self.tolerance, self.contiguous, self.allLayers) = (tool, mode, feather, tolerance, contiguous, allLayers)
    }
}

/// One control of the options bar and the command it feeds.
public enum AreaControl: String, CaseIterable, Hashable, Sendable {
    case tool, mode, feather, tolerance, contiguous, allLayers = "all-layers"
    public var identifier: String { "suite.area.\(rawValue)" }

    /// The command the control's value goes to with `tool` chosen.
    public func command(_ tool: AreaTool) -> String {
        switch self {
        case .tool, .mode: tool.command
        case .feather: "select.feather"
        case .tolerance, .contiguous, .allLayers: AreaTool.wand.command
        }
    }

    /// The controls `tool` shows, top to bottom.
    public static func shown(_ tool: AreaTool) -> [AreaControl] {
        tool == .wand ? allCases : [.tool, .mode, .feather]
    }

    static let feathers: ClosedRange<Double> = 0...250, tolerances: ClosedRange<Double> = 0...255
}

public struct AreaToolOptions: View {
    let options: AreaOptions, onChange: @MainActor (AreaControl, AreaOptions) -> Void
    /// The modifier keys held now. Presentation state only.
    @State private var held = EditModifiers()
    /// The Feather or Tolerance value a gesture is moving, sent to the host when it ends. Presentation state only.
    @State private var scrubbing: [AreaControl: Double] = [:]

    public init(options: AreaOptions, onChange: @escaping @MainActor (AreaControl, AreaOptions) -> Void) {
        (self.options, self.onChange) = (options, onChange)
    }

    nonisolated static let tools = AreaTool.allCases.map {
        InspectorOption(id: $0, title: $0.title, identifier: "suite.area.tool-\($0.rawValue)")
    }
    nonisolated static let modes = AreaCombine.allCases.map {
        InspectorOption(id: $0, title: $0.rawValue.capitalized, identifier: "suite.area.mode-\($0.rawValue)")
    }

    /// The mode the chip shows: the held keys' when Shift or Option is down, else `chosen`.
    nonisolated static func shownMode(_ chosen: AreaCombine, held: EditModifiers) -> AreaCombine {
        held.contains(.shift) || held.contains(.option) ? AreaCombine(held) : chosen
    }

    /// SwiftUI's held keys as the kernel's: Shift and Option.
    nonisolated static func modifiers(_ keys: EventModifiers) -> EditModifiers {
        (keys.contains(.shift) ? EditModifiers.shift : []).union(keys.contains(.option) ? .option : [])
    }

    public var body: some View {
        let shown = AreaControl.shown(options.tool)
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ChoiceChips(options: Self.tools, selected: options.tool) { tool in send(.tool) { $0.tool = tool } }
            ChoiceChips(options: Self.modes, selected: Self.shownMode(options.mode, held: held)) { mode in send(.mode) { $0.mode = mode } }
            bar("Feather", .feather, value: options.feather, range: AreaControl.feathers, unit: "px")
            if shown.contains(.tolerance) {
                bar("Tolerance", .tolerance, value: options.tolerance, range: AreaControl.tolerances, unit: "")
                check("Contiguous", .contiguous, on: options.contiguous)
                check("All Layers", .allLayers, on: options.allLayers)
            }
        }
        .onModifierKeysChanged(mask: [.shift, .option]) { _, keys in held = Self.modifiers(keys) }
    }

    /// A whole-number bar that shows the value being dragged and sends it to the host once, as the gesture ends.
    private func bar(_ title: String, _ control: AreaControl, value: Double, range: ClosedRange<Double>, unit: String) -> some View {
        InspectorSliderRow(title, value: scrubbing[control] ?? value, in: range, step: 1, unit: unit, decimals: 0) {
            scrubbing[control] = $0
            onChange(control, options)
        } onEnd: {
            guard let end = scrubbing.removeValue(forKey: control) else { return }
            send(control) { if control == .feather { $0.feather = end } else { $0.tolerance = end } }
        }
        .accessibilityIdentifier(control.identifier)
    }

    private func check(_ title: String, _ control: AreaControl, on: Bool) -> some View {
        InspectorRow("") {
            Toggle(title, isOn: Binding(get: { on }, set: { value in
                send(control) { if control == .contiguous { $0.contiguous = value } else { $0.allLayers = value } }
            }))
                .toggleStyle(.checkbox)
                .suiteControl(id: control.identifier, enabled: true, reason: nil)
        }
    }

    private func send(_ control: AreaControl, _ change: (inout AreaOptions) -> Void) {
        var next = options
        change(&next)
        onChange(control, next)
    }
}
