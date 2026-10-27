// GalleryEyedropper.swift (eyedropper EY-2 page, EY-7 live): the gallery's `eyedropper` page. A colour row (blue,
// sampleable, its hex field `suite.gallery.eyedropper.hex`) over a small canvas of a red, a green and a half-transparent black
// swatch on white paper, the page's eyedropper tool (`suite.gallery.eyedropper.tool`), the sample-size chips and the
// page's log. The page drives a local SampleTarget with a History: the tool's click runs `color.sample` through the
// board's catalog and the row takes the colour as one `Sample Colour` step; a row pick is one `Colour` step. While the
// tool is on, the loupe follows the pointer over the canvas; only its own layer reads the pointer.
import Observation
import SuiteKernel
import SwiftUI

enum GalleryEyedropper {
    static let name = "eyedropper"
    static let logID = "suite.gallery.eyedropper.log"

    @MainActor static let pages: GalleryPages = [name: { AnyView(EyedropperPage()) }]
}

/// The page's local document: the row's colour, its History, the sample size and the canvas it samples.
struct GalleryEyedropperBoard: SampleTarget {
    /// One swatch on the canvas: identifier suffix, colour, opacity and its rect in canvas points.
    struct Swatch: Sendable {
        let id: String, color: HexColor, opacity: Double, rect: Rect
    }

    static let side = Double(SuiteSize.inspectorField), gap = Double(SuiteSpacing.s)
    /// The canvas: three swatches in a row, `gap` apart and from the edges.
    static let width = 3 * side + 4 * gap, height = side + 2 * gap
    /// The canvas's paper, `SuiteColor.overlayPaper` (white).
    static let paper = HexColor(255, 255, 255)
    static let swatches: [Swatch] = [("red", HexColor(255, 0, 0), 1.0), ("green", HexColor(0, 255, 0), 1.0), ("black", HexColor.black, 0.5)]
        .enumerated().map { index, swatch in
            let minX = gap + Double(index) * (side + gap)
            return Swatch(id: swatch.0, color: swatch.1, opacity: swatch.2,
                          rect: Rect(minX: minX, minY: gap, maxX: minX + side, maxY: gap + side))
        }

    private(set) var color = HexColor(0, 0, 255)
    private(set) var history = History<HexColor>()
    private(set) var size = SampleSize.point

    var sampleHelp: String? { nil }

    static let catalog = try? CommandCatalog<GalleryEyedropperBoard>(
        app: "gallery", SampleCommands.specs(GalleryEyedropperBoard.self), history: { $0.history })

    /// The mean of the square at `point` over the canvas's pixels; nil off the canvas.
    func sampledColor(at point: Point, size: SampleSize) -> FillColor? {
        guard point.x.isFinite, point.y.isFinite, abs(point.x) < 1e6, abs(point.y) < 1e6 else { return nil }
        return SampleRules.mean(x: Int(point.x.rounded(.down)), y: Int(point.y.rounded(.down)), size: size, read: Self.pixel)
    }

    /// The pixel a person sees at (x, y): the swatch over the paper, blended by its opacity; nil off the canvas.
    static func pixel(_ x: Int, _ y: Int) -> SampleRGBA? {
        let (px, py) = (Double(x) + 0.5, Double(y) + 0.5)
        guard px >= 0, py >= 0, px < width, py < height else { return nil }
        let swatch = swatches.first { px >= $0.rect.minX && px < $0.rect.maxX && py >= $0.rect.minY && py < $0.rect.maxY }
        func blend(_ ink: UInt8, _ under: UInt8) -> UInt8 {
            let opacity = swatch?.opacity ?? 0
            return UInt8(min(max(Double(ink) * opacity + Double(under) * (1 - opacity), 0), 255).rounded())
        }
        let ink = swatch?.color ?? paper
        return SampleRGBA(r: blend(ink.red, paper.red), g: blend(ink.green, paper.green), b: blend(ink.blue, paper.blue), a: 255)
    }

    /// What the loupe shows at `point` (canvas points) at the current size.
    func loupeColor(at point: CGPoint) -> HexColor? {
        sampledColor(at: Point(x: Double(point.x), y: Double(point.y)), size: size).flatMap { HexColor(SampleRules.hex($0)) }
    }

    /// A row change (the screen sampler or the hex field): one `Colour` step until `endPick`.
    mutating func pick(_ next: HexColor) -> String {
        if next != color {
            history.record("Colour", color, key: "pick")
            color = next
        }
        return "change \(next.text)"
    }

    /// The row's gesture ended: the next pick is its own step.
    mutating func endPick() -> String {
        history.endRun()
        return "end"
    }

    mutating func choose(size next: SampleSize) -> String {
        size = next
        return "size \(next.title)"
    }

    /// The tool's click at `point` (canvas points): `color.sample` through the catalog; the row takes its colour as
    /// one `Sample Colour` step. The log line.
    mutating func sample(at point: CGPoint) -> String {
        let (x, y) = (Double(point.x).rounded(.down), Double(point.y).rounded(.down))
        guard x.isFinite, y.isFinite, abs(x) < 1e6, abs(y) < 1e6 else { return "color.sample: no colour here" }
        let call = "color.sample {\"x\":\(Int(x)),\"y\":\(Int(y)),\"size\":\(size.rawValue)}"
        guard let catalog = Self.catalog else { return "\(call): no catalog" }
        let params = JSONValue.object(["x": .number(x), "y": .number(y), "size": .number(Double(size.rawValue))])
        let outcome: CommandOutcome
        do { outcome = try catalog.run("color.sample", params: params, on: &self) } catch { return "\(call): refused, \(error)" }
        guard case .object(let fields) = outcome.result, case .object(let sampled)? = fields["color"],
              case .string(let hex)? = sampled["hex"], let next = HexColor(hex) else { return "\(call): no colour here" }
        guard next != color else { return "\(call): \(next.text), no change" }
        history.endRun()
        history.record("Sample Colour", color)
        color = next
        return "\(call): \(next.text), Sample Colour, \(history.steps.count) in History"
    }

    /// Undoes the last step; false when there is none.
    mutating func undo() -> Bool {
        var current = color
        let undid = history.undo { old in
            defer { current = old }
            return current
        }
        color = current
        return undid
    }
}

/// Where the tool's pointer is over the canvas; read only by the loupe's layer, so a move never runs the page's body.
@MainActor @Observable final class EyedropperPointer {
    private(set) var point: CGPoint?
    private(set) var color: HexColor?

    func move(to point: CGPoint?, color: HexColor?) { (self.point, self.color) = (point, color) }
}

private struct EyedropperPage: View {
    @State private var board = GalleryEyedropperBoard()
    @State private var tool = false
    @State private var pointer = EyedropperPointer()
    @State private var lines: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            InspectorColorWellRow("Fill", color: board.color, sampleable: true, onChange: { next in
                lines.append(board.pick(next))
            }, onEnd: { lines.append(board.endPick()) })
            .hexIdentifier("suite.gallery.eyedropper.hex")
            .suiteControl(id: "suite.gallery.eyedropper.hex", enabled: true, reason: nil, identifies: false)
            HStack(spacing: SuiteSpacing.s) {
                Toggle(isOn: $tool) {
                    Label("Eyedropper", systemImage: "eyedropper")
                }
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
                .help("Eyedropper: click the canvas to set the colour")
                .accessibilityLabel("Eyedropper")
                .suiteControl(id: "suite.gallery.eyedropper.tool", enabled: true, reason: nil)
                SampleSizeChips(size: board.size) { next in lines.append(board.choose(size: next)) }
            }
            canvas
            Text(lines.last ?? "Nothing yet")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
                .accessibilityIdentifier(GalleryEyedropper.logID)
                .accessibilityLabel(lines.joined(separator: "\n"))
                .accessibilityValue(lines.joined(separator: "\n"))
            Spacer()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The swatches on the paper; with the tool on, hover moves the loupe and a click samples.
    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            ForEach(GalleryEyedropperBoard.swatches, id: \.id) { swatch in
                Rectangle()
                    .fill(swatch.color.color.opacity(swatch.opacity))
                    .frame(width: swatch.rect.width, height: swatch.rect.height)
                    .accessibilityLabel(swatch.id)
                    .accessibilityIdentifier("suite.gallery.eyedropper.\(swatch.id)")
                    .position(x: (swatch.rect.minX + swatch.rect.maxX) / 2, y: (swatch.rect.minY + swatch.rect.maxY) / 2)
            }
        }
        .frame(width: GalleryEyedropperBoard.width, height: GalleryEyedropperBoard.height, alignment: .topLeading)
        .onChange(of: tool) { if !tool { pointer.move(to: nil, color: nil) } }
        .background(SuiteColor.overlayPaper)
        .contentShape(.rect)
        .onContinuousHover { phase in
            guard tool, case .active(let point) = phase else { return pointer.move(to: nil, color: nil) }
            pointer.move(to: point, color: board.loupeColor(at: point))
        }
        .onTapGesture { point in
            guard tool else { return }
            lines.append(board.sample(at: point))
        }
        .overlay(alignment: .topLeading) { EyedropperLoupeLayer(pointer: pointer) }
    }
}

/// The only view that reads the pointer: the loupe while the tool is over the canvas.
private struct EyedropperLoupeLayer: View {
    let pointer: EyedropperPointer

    var body: some View {
        if let point = pointer.point { SampleLoupe(color: pointer.color, at: point) }
    }
}
