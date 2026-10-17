// FlareInspectorScene.swift: the SCENE section with nothing selected
// (inspector-timeline IT-6): the selected scene's Width, Height and Duration
// as bar sliders (`flare.inspector.scene.width`, `.height`, `.duration`),
// Background as the color row, Frame Rate as a picker
// (`flare.inspector.scene.fps`, its value "24 fps"), and the canvas presets
// as a grid that sets the size. A bar drag or typed value draws on the row's
// own state and goes out once on its end, so each edit is one undo step; a
// pick goes out at once. Every change is an `.inspector` intent
// (`setSceneSize`, `setSceneBackground`, `setSceneTiming`), routed in
// FlareWindow+Inspector.swift; a row the router can't act on is disabled
// with its reason. It only reads `model`.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI

struct FlareInspectorScene: View {
    let model: FlareWorkspace
    let perform: @MainActor (FlareIntent) -> Void

    var body: some View {
        if let scene = model.selectedScene {
            let sizeHelp = FlareWindow.inspectorHelp(.setSceneSize(width: 1, height: 1), in: model)
            let timingHelp = FlareWindow.inspectorHelp(.setSceneTiming(fps: 1, durationFrames: 1), in: model)
            let sides = 1...NewDocumentSpec.maxSide
            let frames = Double(NewDocumentSpec.durationRange.lowerBound)...Double(NewDocumentSpec.durationRange.upperBound)
            InspectorSection("Scene") {
                FlareSceneNumberRow(title: "Width", id: "width", value: scene.width, range: sides, unit: "px", help: sizeHelp) {
                    perform(.inspector(.setSceneSize(width: $0, height: scene.height)))
                }
                FlareSceneNumberRow(title: "Height", id: "height", value: scene.height, range: sides, unit: "px", help: sizeHelp) {
                    perform(.inspector(.setSceneSize(width: scene.width, height: $0)))
                }
                InspectorColorWellRow("Background", color: Self.hex(scene.background)) {
                    perform(.inspector(.setSceneBackground(hex: $0.text)))
                }
                InspectorPickerRow("Frame Rate", options: Self.rates(including: scene.fps), selection: scene.fps) {
                    perform(.inspector(.setSceneTiming(fps: $0, durationFrames: scene.durationFrames)))
                }
                .disabled(timingHelp != nil)
                .help(timingHelp ?? "Frame Rate")
                .accessibilityValue(Text(verbatim: "\(scene.fps) fps"))
                .accessibilityIdentifier("flare.inspector.scene.fps")
                FlareSceneNumberRow(
                    title: "Duration", id: "duration", value: Double(scene.durationFrames), range: frames, unit: "frames",
                    help: timingHelp
                ) { perform(.inspector(.setSceneTiming(fps: scene.fps, durationFrames: Int($0.rounded())))) }
                PresetGrid(
                    options: CanvasPreset.all.map { InspectorOption(id: $0.name, title: $0.name) },
                    selected: CanvasPreset.all.first { $0.width == scene.width && $0.height == scene.height }?.name,
                    columns: 2
                ) { name in
                    if let preset = CanvasPreset.all.first(where: { $0.name == name }) {
                        perform(.inspector(.setSceneSize(width: preset.width, height: preset.height)))
                    }
                }
                .disabled(sizeHelp != nil)
                .help(sizeHelp ?? "Canvas size presets")
                // On the grid, so each preset button reads it (SuiteUI has no per-option id yet, #1148).
                .accessibilityIdentifier("flare.inspector.scene.preset")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("flare.inspector.scene")
        }
    }

    /// The scene's background as the color row's 8-bit color.
    private static func hex(_ color: FlareColor) -> HexColor {
        HexColor(NewDocumentSpec.hex(color)) ?? HexColor(255, 255, 255)
    }

    /// The New sheet's frame rates, with `fps` added in order when it isn't one of them.
    private static func rates(including fps: Int) -> [InspectorOption<Int>] {
        Set(NewDocumentSpec.frameRates + [fps]).sorted().map { InspectorOption(id: $0, title: "\($0) fps") }
    }
}

/// One whole-number SCENE bar. A drag, arrow or typed value shows on the row's
/// own `pending` value and goes out through `commit` once, on its end.
struct FlareSceneNumberRow: View {
    let title: String
    let id: String
    let value: Double
    let range: ClosedRange<Double>
    let unit: String
    /// Why the row can't act; nil while it can.
    let help: String?
    let commit: @MainActor (Double) -> Void
    /// The value shown while a drag or typed edit is under way; nil between edits.
    @State private var pending: Double?

    var body: some View {
        InspectorSliderRow(
            title, value: pending ?? value, in: range, step: 1, unit: unit, decimals: 0,
            onChange: { pending = $0 },
            onEnd: {
                if let next = pending, next != value { commit(next) }
                pending = nil
            })
            .accessibilityIdentifier("flare.inspector.scene.\(id)")
            .disabled(help != nil)
            .help(help ?? title)
    }
}
