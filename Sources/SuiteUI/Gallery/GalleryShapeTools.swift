// GalleryShapeTools.swift: the gallery's `shape-tools` page (shape-tools SH-2). ShapeToolOptions over a canvas
// whose drag draws `ShapeRules.dragged`'s box (the plain one while that stub answers nil); each step logs a line.
import AppKit
import SuiteKernel
import SwiftUI

enum GalleryShapeTools { static let name = "shape-tools" }

struct GalleryShapeToolsPage: View {
    @State private var spec = ShapeSpec.defaults(.rectangle)
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Shape tool").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText).accessibilityAddTraits(.isHeader)
            ShapeToolOptions(spec: spec, help: ShapeRules.help(spec)) { intent in
                spec = intent.applied(to: spec)
                log.append("\(intent.command.id) \(intent)")
            }
            GalleryShapeCanvas(kind: spec.kind) { box in
                log.append("drag \(spec.kind.rawValue) \(Int(box.width)) x \(Int(box.height))")
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(log.joined(separator: "\n"))
                .accessibilityValue(log.joined(separator: "\n"))
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The page's canvas, with its own drag state so a drag sample redraws only it.
private struct GalleryShapeCanvas: View {
    let kind: ShapeKind
    let onDrawn: @MainActor (Rect) -> Void
    @State private var box: Rect?

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
                    let (from, to) = (Point(x: value.startLocation.x, y: value.startLocation.y), Point(x: value.location.x, y: value.location.y))
                    let flags = NSEvent.modifierFlags
                    let held = EditModifiers(rawValue: (flags.contains(.shift) ? 1 : 0) | (flags.contains(.option) ? 2 : 0))
                    box = ShapeRules.dragged(kind, from: from, to: to, modifiers: held)?.box ?? Rect(enclosing: [from, to])
                }
                .onEnded { _ in if let box { onDrawn(box) } })
        .accessibilityElement().accessibilityLabel("Shape canvas")
        .accessibilityValue(box.map { "\(Int($0.width)) x \(Int($0.height))" } ?? "Empty")
        .accessibilityIdentifier("suite.gallery.shape-canvas")
    }
}
