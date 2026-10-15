// HaloViewerCanvas.swift: the artboard in Halo's viewer (#37). CanvasSurface
// sized to the selected composition, with the Model's `viewerDrawList` drawn
// over the artboard's fitted frame in one SwiftUI Canvas, bottom layer first,
// in linear light as LiveFrameRendering composites (the Canvas's colorMode
// and its drawing group both .linear): each item at its matrix times the fit,
// at its opacity and blend mode; a solid fills its box, a shape the ellipse in it, a text layer
// is a resolved Text on the pinned baseline rule (its line box's top-left at
// bounds.origin, its first baseline at bounds.y + ascent). The selected
// layer's world box gets SuiteUI's SelectionOutline. The frame Render Frame
// shows (HaloRenderedFrameView) and the viewer's gestures (HaloViewerGestures)
// sit over it. The artboard's value is `viewerSummary` ("Frame 30:
// Background, Badge, Title: Hello Halo"); its child `halo.viewer.canvas` reads
// `drawnSummary` ("2 layers drawn"). It reads its model and never acts.
import CoreRaster
import CoreText
import HaloModel
import SuiteUI
import SwiftUI

struct HaloViewerCanvas: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        let comp = model.selectedComposition
        let artboard = CGSize(width: max(comp?.width ?? 1, 1), height: max(comp?.height ?? 1, 1))
        CanvasSurface(artboard: artboard)
            // CanvasSurface draws a flat artboard; the layers cover its fitted
            // frame, laid out the same way.
            .overlay {
                if let list = model.viewerDrawList {
                    HaloDrawnLayers(list: list, selectedLayerID: model.selectedLayerID)
                        .aspectRatio(artboard, contentMode: .fit)
                        .frame(maxWidth: artboard.width, maxHeight: artboard.height)
                        .padding(SuiteSize.canvasInset)
                }
            }
            .overlay { HaloRenderedFrameView(model: model, perform: perform) }
            .overlay { HaloViewerGestures(model: model, perform: perform) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Artboard")
            .accessibilityValue(model.viewerSummary)
            .accessibilityIdentifier("halo.viewer")
    }
}

/// One frame's draw list over the artboard's fitted frame, and the selected
/// layer's outline. Composition pixels times `size / list size` is the fit.
private struct HaloDrawnLayers: View {
    let list: HaloDrawList
    let selectedLayerID: String?

    var body: some View {
        let list = list
        // The Canvas's own working space must be linear: its default
        // (.nonLinear) mixes each item's opacity in sRGB inside the Canvas,
        // before the linear drawing group ever sees it (HF-1 keyed-6, #1161).
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: false) { context, size in
            let fit = HaloCanvasFit.transform(list: list, size: size)
            for item in list.items {
                drawItem(item, in: context, fit: fit)
            }
        }
        .drawingGroup(opaque: false, colorMode: .linear)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Layers")
        .accessibilityValue(list.drawnSummary)
        .accessibilityIdentifier("halo.viewer.canvas")
        .overlay {
            GeometryReader { proxy in
                if let id = selectedLayerID, let box = list.worldBox(of: id) {
                    SelectionOutline(
                        rect: CGRect(x: box.x, y: box.y, width: box.width, height: box.height),
                        zoom: HaloCanvasFit.scale(list: list, size: proxy.size))
                }
            }
        }
    }
}

/// Draws one item bottom first into its own copy of `context`.
private func drawItem(_ item: HaloDrawItem, in context: GraphicsContext, fit: CGAffineTransform) {
    var g = context
    let m = item.matrix
    g.concatenate(CGAffineTransform(a: m.a, b: m.b, c: m.c, d: m.d, tx: m.tx, ty: m.ty).concatenating(fit))
    g.opacity = item.opacity
    g.blendMode = HaloCanvasFit.blendMode(item.blendMode)
    let b = item.bounds
    let rect = CGRect(x: b.x, y: b.y, width: b.width, height: b.height)
    let color = Color(cgColor: HaloCanvasFit.cgColor(item.color))
    switch item.kind {
    case .solid: g.fill(Path(rect), with: .color(color))
    case .shape: g.fill(Path(ellipseIn: rect), with: .color(color))
    case .text:
        guard let content = item.text else { return }
        let size = CGFloat(content.fontSize)
        let resolved = g.resolve(Text(content.string).font(.system(size: size)).foregroundStyle(color))
        let box = CGSize(width: max(rect.width, 1), height: max(rect.height, 1))
        let ascent = HaloCanvasFit.ascent(fontSize: size)
        let at = CGPoint(x: rect.minX, y: rect.minY + ascent - resolved.firstBaseline(in: box))
        g.draw(resolved, at: at, anchor: .topLeading)
    case .null: break
    }
}

/// The canvas's pure mappings: the fit, the blend switch, document colors.
enum HaloCanvasFit {
    /// Points per composition pixel; 1 for a list with no size.
    static func scale(list: HaloDrawList, size: CGSize) -> Double {
        guard list.width > 0 else { return 1 }
        let s = Double(size.width) / Double(list.width)
        return s.isFinite && s > 0 ? s : 1
    }

    /// Composition pixels to canvas points.
    static func transform(list: HaloDrawList, size: CGSize) -> CGAffineTransform {
        guard list.width > 0, list.height > 0 else { return .identity }
        return CGAffineTransform(
            scaleX: size.width / CGFloat(list.width), y: size.height / CGFloat(list.height))
    }

    /// Every W3C blend mode CoreRaster knows, as the context's own.
    static func blendMode(_ mode: CoreRaster.BlendMode) -> GraphicsContext.BlendMode {
        switch mode {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        case .overlay: .overlay
        case .darken: .darken
        case .lighten: .lighten
        case .colorDodge: .colorDodge
        case .colorBurn: .colorBurn
        case .hardLight: .hardLight
        case .softLight: .softLight
        case .difference: .difference
        case .exclusion: .exclusion
        case .hue: .hue
        case .saturation: .saturation
        case .color: .color
        case .luminosity: .luminosity
        }
    }

    /// The system font's ascent at `fontSize`, the font `.system(size:)`
    /// draws with; 0.8 em when Core Text gives no font.
    static func ascent(fontSize: CGFloat) -> CGFloat {
        guard let font = CTFontCreateUIFontForLanguage(.system, fontSize, nil) else { return fontSize * 0.8 }
        return CTFontGetAscent(font)
    }

    /// A layer's color as an opaque sRGB CGColor.
    static func cgColor(_ color: HaloLayerColor) -> CGColor {
        CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
    }
}
