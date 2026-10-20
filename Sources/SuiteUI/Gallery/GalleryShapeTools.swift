// GalleryShapeTools.swift: the gallery's `shape-tools` page (packet
// docs/blueprints/suiteui/features/shape-tools.md, SH-2; SH-7 draws through
// shape.draw). It shows ShapeToolOptions over a canvas. A drag on the canvas
// draws its box: `ShapeRules.dragged` (a stub answering nil until SH-5), or
// the press-to-pointer box while it does. Each option change and each drag
// writes one line to the `suite.gallery.log` element the journey reads.
import AppKit
import SuiteKernel
import SwiftUI

enum GalleryShapeTools {
    static let name = "shape-tools"

    /// The box a drag from `from` to `to` draws for `kind`: the rules' box, or the plain one until SH-5.
    nonisolated static func box(_ kind: ShapeKind, from: Point, to: Point, modifiers: EditModifiers) -> Rect? {
        ShapeRules.dragged(kind, from: from, to: to, modifiers: modifiers)?.box ?? Rect(enclosing: [from, to])
    }

    /// Shift, Option and Command from AppKit's flags.
    nonisolated static func modifiers(_ flags: NSEvent.ModifierFlags) -> EditModifiers {
        var held = EditModifiers()
        if flags.contains(.shift) { held.insert(.shift) }
        if flags.contains(.option) { held.insert(.option) }
        if flags.contains(.command) { held.insert(.command) }
        return held
    }
}

struct GalleryShapeToolsPage: View {
    @State private var spec = ShapeSpec.defaults(.rectangle)
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Shape tool")
                .font(SuiteFont.sectionCaps)
                .foregroundStyle(SuiteColor.secondaryText)
                .accessibilityAddTraits(.isHeader)
            ShapeToolOptions(spec: spec, help: ShapeRules.help(spec)) { intent in
                spec = intent.applied(to: spec)
                write("\(intent.command.id) \(intent)")
            }
            GalleryShapeCanvas(kind: spec.kind) { box in
                write("drag \(spec.kind.rawValue) \(Int(box.width)) x \(Int(box.height))")
            }
            Text(log.last ?? "Nothing yet")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
                .lineLimit(1)
                .accessibilityLabel(log.joined(separator: "\n"))
                .accessibilityValue(log.joined(separator: "\n"))
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func write(_ line: String) {
        log.append(line)
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}

/// The page's canvas: its own drag state, so a drag sample redraws only this view.
private struct GalleryShapeCanvas: View {
    let kind: ShapeKind
    let onDrawn: @MainActor (Rect) -> Void
    @State private var box: Rect?
    @State private var press: CGPoint?

    var body: some View {
        let shown = box
        Canvas { context, _ in
            guard let shown else { return }
            let rect = CGRect(x: shown.minX, y: shown.minY, width: shown.width, height: shown.height)
            context.stroke(Path(rect), with: .color(SuiteColor.overlayInk), lineWidth: 1)
        }
        .frame(width: SuiteSize.contentMinimum.width, height: SuiteSize.contentMinimum.height)
        .background(SuiteColor.artboard)
        .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let start = press ?? value.startLocation
                    press = start
                    box = GalleryShapeTools.box(kind, from: Point(x: start.x, y: start.y),
                                                to: Point(x: value.location.x, y: value.location.y),
                                                modifiers: GalleryShapeTools.modifiers(NSEvent.modifierFlags))
                }
                .onEnded { _ in
                    press = nil
                    if let box { onDrawn(box) }
                })
        .accessibilityElement()
        .accessibilityLabel("Shape canvas")
        .accessibilityValue(box.map { "\(Int($0.width)) x \(Int($0.height))" } ?? "Empty")
        .accessibilityIdentifier("suite.gallery.shape-canvas")
    }
}
