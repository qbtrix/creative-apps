// HaloPlace.swift (placed-images PH-3): the app's glue for placing a picture on a solid. The window hands its
// views one `haloPlace` action (environment and focused scene value) that runs a PlaceIntent, with the Fill
// preference, through `HaloProject.runPlace`, the catalog's `place.*` commands (PH-6). File > Place… ⇧⌘P
// (HaloPlaceMenuAdapter) opens SuiteUI's PlacePanel for PNG, JPEG and SVG and places each file centred; the viewer's
// drop (HaloViewer) places at the drop point in composition pixels (`compositionPoint`). Both are off with
// `help` as their reason while the Model's `placeHelp` gives one or no action is wired. ⌥-drag on a selected solid
// with a picture (HaloPlaceFocusDrag) pans its focus: each sample shows through HaloLiveEdit, the release sends
// one `place.focus` under the drag's token, so the Model records one step. The pan ignores the layer's own scale
// and rotation. Views stay dumb: they call the action, never the project.
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// Runs one place intent; the Bool is the Fill preference, used by `.place`.
typealias HaloPlaceAction = @MainActor (PlaceIntent, Bool) -> Void

extension EnvironmentValues {
    /// The window's place action; nil outside a window that wires it.
    @Entry var haloPlace: HaloPlaceAction?
}

extension FocusedValues {
    /// The focused window's place action, for File > Place….
    @Entry var haloPlace: HaloPlaceAction?
}

enum HaloPlace {
    /// The Fill checkbox's preference: a placed file fills the selected solid.
    static let fillKey = "halo.place.fill"
    static let notWired = "Placing isn't connected in this window yet."
    static let noProject = "Open or create a composition to place an image."

    /// Why Place can't run now; nil while it can.
    static func help(_ model: HaloProject?, _ place: HaloPlaceAction?) -> String? {
        guard let model else { return noProject }
        return model.placeHelp ?? (place == nil ? notWired : nil)
    }

    /// The focus after panning `image` by `panned` composition pixels from its own focus; an axis the picture
    /// overflows by under a pixel (the cover scale's rounding) keeps its focus.
    static func focus(_ image: PlacedImage, natural: Size, panned: CGSize) -> Point {
        let drawn = PlaceRules.drawnRect(image, natural: natural), box = image.box
        func axis(_ focus: Double, _ excess: Double, _ delta: Double) -> Double {
            excess >= 1 ? min(max(focus - delta / excess, 0), 1) : focus
        }
        return Point(
            x: axis(image.focus.x, drawn.width - box.width, Double(panned.width)),
            y: axis(image.focus.y, drawn.height - box.height, Double(panned.height)))
    }

    /// Composition pixels per viewer point: the artboard fitted inside the canvas inset, never above 100%.
    static func pixelsPerPoint(viewer: CGSize, composition: CGSize) -> Double? {
        let inset = 2 * Double(SuiteSize.canvasInset)
        let (w, h) = (Double(composition.width), Double(composition.height))
        guard w > 0, h > 0 else { return nil }
        let scale = min((Double(viewer.width) - inset) / w, (Double(viewer.height) - inset) / h, 1)
        return scale > 0 ? 1 / scale : nil
    }

    /// `point` in the viewer as composition pixels; nil off the artboard (the place then centres).
    static func compositionPoint(_ point: CGPoint, viewer: CGSize, composition: CGSize) -> Point? {
        guard let perPoint = pixelsPerPoint(viewer: viewer, composition: composition) else { return nil }
        let x = (Double(point.x) - Double(viewer.width) / 2) * perPoint + Double(composition.width) / 2
        let y = (Double(point.y) - Double(viewer.height) / 2) * perPoint + Double(composition.height) / 2
        guard (0...Double(composition.width)).contains(x), (0...Double(composition.height)).contains(y) else { return nil }
        return Point(x: x, y: y)
    }
}

extension HaloProject {
    /// Runs `intent` through the catalog's `place.*` command; `fill` rides on a `.place`. A refusal changes nothing.
    mutating func runPlace(_ intent: PlaceIntent, fill: Bool = false) {
        var command = intent.command
        if case .place = intent, case .object(var params) = command.params {
            params["fill"] = .bool(fill)
            command.params = .object(params)
        }
        _ = try? Self.catalog.run(command.id, params: command.params, on: &self)
    }
}

/// ⌥-drag on the selected solid's picture pans its focus (one `place.focus` step per drag).
struct HaloPlaceFocusDrag: ViewModifier {
    let model: HaloProject
    @Environment(\.haloPlace) private var place
    @Environment(\.haloLiveEdit) private var live
    @State private var size = CGSize.zero
    @State private var token: String?
    @State private var last: Point?

    func body(content: Content) -> some View {
        let on = place != nil && model.placedSelection != nil
        content
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .highPriorityGesture(drag, including: on ? .all : .subviews)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1)
            .modifiers(.option)
            .onChanged { value in
                guard let picked = model.placedSelection, let comp = model.selectedComposition,
                    let perPoint = HaloPlace.pixelsPerPoint(
                        viewer: size, composition: CGSize(width: comp.width, height: comp.height))
                else { return }
                let id = token ?? UUID().uuidString
                token = id
                let panned = CGSize(width: value.translation.width * perPoint, height: value.translation.height * perPoint)
                let focus = HaloPlace.focus(picked.image, natural: picked.asset.natural, panned: panned)
                last = focus
                if let live {
                    live.show { $0.runPlace(.focus(focus, drag: id)) }
                } else {
                    place?(.focus(focus, drag: id), false)
                }
            }
            .onEnded { _ in
                if let token, let last { place?(.focus(last, drag: token), false) }
                (token, last) = (nil, nil)
                live?.project = nil
            }
    }
}

/// File > Place… ⇧⌘P: the panel for PNG, JPEG and SVG, then each chosen file placed centred. The catalog's
/// `place.image` spec decides whether it is on and what its help says; a window with no place action wired has
/// nothing to send to, so it reads as no window.
struct HaloPlaceMenuAdapter: View {
    let model: HaloProject?
    let place: HaloPlaceAction?
    @AppStorage(HaloPlace.fillKey) private var fill = false

    var body: some View {
        MenuCommand(
            HaloMenuState.spec("place.image"), on: HaloMenuState(project: place == nil ? nil : model), title: "Place…",
            systemImage: "photo.badge.plus", shortcut: KeyboardShortcut("p", modifiers: [.command, .shift])
        ) {
            guard let model, let place else { return }
            let (formats, fill) = (model.placeFormats, fill)
            Task { @MainActor in
                for file in await PlacePanel.choose(formats: formats) {
                    place(.place(name: file.name, data: file.data, at: nil), fill)
                }
            }
        }
    }
}
