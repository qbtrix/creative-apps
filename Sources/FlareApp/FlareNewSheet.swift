// FlareNewSheet.swift: the New Animation sheet (layers-files LF-3), which
// File > New, the toolbar's New and the empty state present: a preset or
// Custom, size, frame rate, duration and background. It owns only its draft
// NewDocumentSpec, typed numbers kept as text; `problem` shows under the
// fields and disables Create, which sends `.file(spec.intent)`. Also holds
// FlarePresentation, what the window presents over itself.
import FlareModel
import SuiteUI
import SwiftUI

/// What the window presents over itself; filled by the tasks that present it.
enum FlarePresentation: Hashable, Identifiable {
    case newAnimation

    var id: Self { self }
}

struct FlareNewSheet: ViewModifier {
    @Binding var presented: FlarePresentation?
    let perform: @MainActor (FlareIntent) -> Void

    func body(content: Content) -> some View {
        content.sheet(item: $presented) { _ in
            FlareNewAnimationSheet(
                spec: NewDocumentSpec(preset: .hd1080), onCreate: { perform(.file($0.intent)) },
                onCancel: { presented = nil })
        }
    }
}

struct FlareNewAnimationSheet: View {
    static let custom = "Custom"
    var onCreate: @MainActor (NewDocumentSpec) -> Void
    var onCancel: @MainActor () -> Void
    @State private var spec: NewDocumentSpec
    @State private var widthText: String
    @State private var heightText: String
    @State private var durationText: String

    init(
        spec: NewDocumentSpec, onCreate: @escaping @MainActor (NewDocumentSpec) -> Void = { _ in },
        onCancel: @escaping @MainActor () -> Void = {}
    ) {
        self.onCreate = onCreate
        self.onCancel = onCancel
        _spec = State(initialValue: spec)
        _widthText = State(initialValue: Self.text(spec.width))
        _heightText = State(initialValue: Self.text(spec.height))
        _durationText = State(initialValue: String(spec.durationFrames))
    }

    var body: some View {
        SuiteSheet(
            "New Animation", width: .wide, problem: spec.problem, cancelIdentifier: "flare.new.cancel",
            confirm: .init(
                "Create", identifier: "flare.new.create", help: spec.problem ?? "Create the animation",
                isEnabled: spec.problem == nil) { if spec.problem == nil { onCreate(spec) } },
            onCancel: onCancel
        ) {
            PresetGrid(
                options: (CanvasPreset.all.map(\.name) + [Self.custom]).map {
                    InspectorOption(id: $0, title: $0, identifier: "flare.new.preset.\($0)")
                },
                selected: spec.preset?.name ?? Self.custom, columns: 3, onSelect: pick)
            Form {
                TextField("Width", text: Binding(get: { widthText }, set: { setWidth($0) }))
                    .accessibilityLabel("Width")
                    .accessibilityIdentifier("flare.new.width")
                TextField("Height", text: Binding(get: { heightText }, set: { setHeight($0) }))
                    .accessibilityLabel("Height")
                    .accessibilityIdentifier("flare.new.height")
                Picker("Frame Rate", selection: Binding(get: { spec.fps }, set: { spec.fps = $0 })) {
                    ForEach(NewDocumentSpec.frameRates, id: \.self) { Text("\($0) fps").tag($0) }
                }
                .accessibilityLabel("Frame Rate")
                .accessibilityIdentifier("flare.new.fps")
                TextField("Duration (frames)", text: Binding(get: { durationText }, set: { setDuration($0) }))
                    .accessibilityLabel("Duration (frames)")
                    .accessibilityIdentifier("flare.new.duration")
            }
            .formStyle(.columns)
            InspectorColorWellRow("Background", color: background) { setBackground($0) }
        }
    }

    private var background: HexColor {
        HexColor(NewDocumentSpec.hex(spec.background)) ?? HexColor(255, 255, 255)
    }

    private func pick(_ name: String) {
        spec.pick(CanvasPreset.all.first { $0.name == name })
        (widthText, heightText) = (Self.text(spec.width), Self.text(spec.height))
        durationText = String(spec.durationFrames)
    }

    private func setWidth(_ text: String) {
        widthText = text
        spec.setSize(width: Self.number(text), height: spec.height)
    }

    private func setHeight(_ text: String) {
        heightText = text
        spec.setSize(width: spec.width, height: Self.number(text))
    }

    private func setDuration(_ text: String) {
        (durationText, spec.durationFrames) = (text, Int(text.trimmingCharacters(in: .whitespaces)) ?? 0)
    }

    private func setBackground(_ hex: HexColor) {
        if let color = NewDocumentSpec.color(hex: hex.text) { spec.background = color }
    }

    /// A typed number; text that isn't one in range is 0, which `problem` names.
    private static func number(_ text: String) -> Double {
        let value = Double(text.trimmingCharacters(in: .whitespaces)) ?? 0
        return abs(value) < 1e9 ? value : 0
    }

    private static func text(_ value: Double) -> String { abs(value) < 1e9 ? String(Int(value)) : String(value) }
}
