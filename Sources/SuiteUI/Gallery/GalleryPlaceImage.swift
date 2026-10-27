// GalleryPlaceImage.swift: the gallery's `place-image` page (placed-images PL-2 and PL-3; PL-8 runs it live).
// An 800 × 600 canvas, drawn at half size, that takes dropped files, with Place… (the panel) and two samples whose bytes
// are made here: `Wide PNG`, a 1200 × 400 picture, and `Logo SVG`, 240 × 80 with a red and a blue part. The page drives
// `GalleryPlaceBoard`, a local PlacedImageTarget with a History: every intent (a sample, the panel, a drop, the rows)
// runs through `PlaceCommands` in the board's catalog as one step and writes one line, `<command id> <outcome>`, to
// `suite.gallery.log`. On the canvas a drag on the selected image's right edge resizes its box (one `Resize` step) and
// a ⌥-drag inside it moves the picture in its box (`place.focus` per sample under one drag token: one `Move Inside`).
// The selected image wears the accent outline and a right-edge handle (`SelectionHandles`), and the pointer turns
// into the resize arrow over `edgeStrip`, the band a drag grabs, so the resize is found by mouse. A drop it refuses
// shows why under the canvas. The canvas reads "Image, <name>, W by H pixels" to VoiceOver. The page is its own area
// in `SuiteGallery.areas`.
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import SuiteImaging
import SuiteKernel
import SwiftUI
import UniformTypeIdentifiers

enum GalleryPlaceImage {
    static let name = "place-image"

    static let pages: GalleryPages = [name: { AnyView(GalleryPlaceImagePage()) }]

    /// The canvas the page places into, and the scale it's drawn at.
    static let canvas = Rect(minX: 0, minY: 0, maxX: 800, maxY: 600)
    static let scale = 0.5

    /// A sample the page can place: its file name, bytes and natural size.
    struct Sample {
        let label: String, name: String, format: PlacedFormat, natural: Size, data: Data
    }

    static let samples = [
        Sample(label: "Wide PNG", name: "wide.png", format: .png, natural: Size(width: 1200, height: 400), data: widePNG()),
        Sample(label: "Logo SVG", name: "logo.svg", format: .svg, natural: Size(width: 240, height: 80), data: Data(logoSVG.utf8)),
    ]

    /// 240 × 80: a red part on the left, a blue one on the right.
    static let logoSVG = """
        <svg xmlns="http://www.w3.org/2000/svg" width="240" height="80" viewBox="0 0 240 80">\
        <rect x="0" y="0" width="120" height="80" fill="#ff0000"/><rect x="120" y="0" width="120" height="80" fill="#0000ff"/></svg>
        """

    /// The band (view points) where a drag grabs `image`'s right edge: `GalleryPlaceBoard.edgeSlop` either side of it,
    /// its box's height.
    static func edgeStrip(_ image: PlacedImage) -> CGRect {
        let slop = GalleryPlaceBoard.edgeSlop
        return PlacedImageText.cgRect(
            Rect(minX: image.box.maxX - slop, minY: image.box.minY, maxX: image.box.maxX + slop, maxY: image.box.maxY),
            scale: scale)
    }

    /// The asset and its fitted, centred image for `sample`.
    static func placed(_ sample: Sample) -> (PlacedAsset, PlacedImage) {
        let id = PlaceRules.assetID(of: sample.data)
        let asset = PlacedAsset(
            id: id, name: sample.name, format: PlaceRules.format(of: sample.data) ?? sample.format, natural: sample.natural,
            data: sample.data)
        return (asset, PlacedImage(assetID: id, box: PlaceRules.fitted(natural: sample.natural, in: canvas, at: nil)))
    }

    /// 1200 × 400 PNG bytes: three bands, orange, green and purple; empty if ImageIO can't encode them.
    static func widePNG() -> Data {
        let (width, height) = (1200, 400)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return Data() }
        let bands = [(1.0, 0.6, 0.0), (0.2, 0.7, 0.3), (0.5, 0.3, 0.8)]
        for (index, band) in bands.enumerated() {
            context.setFillColor(CGColor(srgbRed: band.0, green: band.1, blue: band.2, alpha: 1))
            context.fill(CGRect(x: index * width / bands.count, y: 0, width: width / bands.count, height: height))
        }
        let bytes = CFDataCreateMutable(nil, 0)
        guard let image = context.makeImage(), let bytes,
            let destination = CGImageDestinationCreateWithData(bytes, UTType.png.identifier as CFString, 1, nil)
        else { return Data() }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? bytes as Data : Data()
    }
}

/// The page's document: its placed images in paint order, their assets, the selection, and one History step per edit.
struct GalleryPlaceBoard: PlacedImageTarget {
    struct Layer: Hashable, Sendable { var id: String; var image: PlacedImage }
    struct State: Hashable, Sendable { var layers: [Layer] = [], assets = PlacedAssets(), selected: String? }
    /// What a canvas drag grabbed: the selected image's right edge, or its inside with ⌥ held.
    enum Grab: Sendable { case edge, focus }
    /// How near the right edge (canvas points) a drag grabs it, and the narrowest box a resize leaves.
    static let edgeSlop = 12.0, minimumSide = 8.0

    private(set) var state = State(), history = History<State>()

    static let catalog = try? CommandCatalog<GalleryPlaceBoard>(
        app: "gallery", PlaceCommands.specs(GalleryPlaceBoard.self), history: { $0.history })

    var placeHelp: String? { nil }
    var placeCanvas: Rect { GalleryPlaceImage.canvas }
    var placeFillBox: Rect? { nil }
    var placeFormats: Set<PlacedFormat> { Set(PlacedFormat.allCases) }
    var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? {
        guard let layer = state.layers.first(where: { $0.id == state.selected }),
            let asset = state.assets.byID[layer.image.assetID]
        else { return nil }
        return (layer.id, layer.image, asset)
    }
    /// Every image with its asset, in paint order.
    var drawn: [(asset: PlacedAsset, image: PlacedImage)] {
        state.layers.compactMap { layer in state.assets.byID[layer.image.assetID].map { ($0, layer.image) } }
    }

    func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size {
        guard let size = SuiteImaging.rasterSize(of: data) else {
            throw CatalogError.failed(id: "place.image", message: "The file has no readable size.")
        }
        return size
    }

    mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) -> String {
        history.record(name, state)
        let id = "image\(state.layers.count + 1)"
        state.layers.append(Layer(id: id, image: image))
        (state.assets, state.selected) = (state.assets.adding(asset), id)
        return id
    }

    mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) {
        guard let index = state.layers.firstIndex(where: { $0.id == state.selected }) else { return }
        history.record(name, state, key: drag.map { "\(name):\($0)" })
        state.layers[index].image = image
        if let asset { state.assets = state.assets.adding(asset) }
    }

    /// `intent` through the catalog; the log line: `<command id> <undo step>, n in History`, or why it was refused.
    mutating func run(_ intent: PlaceIntent) -> String {
        let (id, params) = intent.command
        guard let catalog = Self.catalog else { return "\(id): no catalog" }
        do {
            let outcome = try catalog.run(id, params: params, on: &self)
            return "\(id) \(outcome.undoStep ?? "no step"), \(history.steps.count) in History"
        } catch { return "\(id): refused, \(error)" }
    }

    /// The right-edge drag: `start`'s box to `right` (its left, top and height kept), one `Resize` step per `drag`.
    mutating func resize(_ start: PlacedImage, right: Double, drag: String) -> String {
        guard right.isFinite else { return "resize: no edge" }
        var image = start
        image.box = Rect(
            minX: start.box.minX, minY: start.box.minY, maxX: max(right, start.box.minX + Self.minimumSide), maxY: start.box.maxY)
        setPlaced(image, asset: nil, name: "Resize", drag: drag)
        return "resize \(PlacedImageText.whole(image.box.width)) × \(PlacedImageText.whole(image.box.height))"
    }

    /// The ⌥-drag: the picture moved `delta` (canvas points) from `start`, as `place.focus` under `drag`. Moving the
    /// picture right shows more of its left, so the focus moves against the drag by the share of the spare room.
    mutating func moveFocus(_ start: PlacedImage, by delta: Point, drag: String) -> String {
        guard let natural = placedSelection?.asset.natural else { return "place.focus: nothing selected" }
        let drawn = PlaceRules.drawnRect(start, natural: natural)
        func moved(_ focus: Double, _ by: Double, _ spare: Double) -> Double {
            spare > 0 && by.isFinite ? min(max(focus - by / spare, 0), 1) : focus
        }
        let focus = Point(
            x: moved(start.focus.x, delta.x, drawn.width - start.box.width),
            y: moved(start.focus.y, delta.y, drawn.height - start.box.height))
        return run(.focus(focus, drag: drag))
    }

    /// The canvas drag ended: the next drag is its own step.
    mutating func endDrag() { history.endRun() }

    /// What a drag starting at `point` (canvas points) grabs of `image`: its right edge, or its inside with ⌥ held.
    static func grab(_ image: PlacedImage, at point: Point, option: Bool) -> Grab? {
        let box = image.box
        guard point.y >= box.minY, point.y <= box.maxY else { return nil }
        if abs(point.x - box.maxX) <= edgeSlop { return .edge }
        return option && point.x >= box.minX && point.x <= box.maxX ? .focus : nil
    }

    /// Undoes the last step; false when there is none.
    mutating func undo() -> Bool {
        var current = state
        let undid = history.undo { old in
            defer { current = old }
            return current
        }
        state = current
        return undid
    }
}

/// One canvas drag: its token, what it grabbed, and the image as it began.
private struct GalleryPlaceDrag {
    let token: String, grab: GalleryPlaceBoard.Grab, start: PlacedImage
}

/// The `place-image` page: the canvas, Place… and the samples, the file row once placed, and the log.
struct GalleryPlaceImagePage: View {
    @State private var board: GalleryPlaceBoard
    @State private var drag: GalleryPlaceDrag?
    @State private var log: [String] = []
    @State private var refused: String?

    /// The page on `board`; snapshots pass one with an image placed.
    init(board: GalleryPlaceBoard = GalleryPlaceBoard()) { _board = State(initialValue: board) }

    var body: some View {
        let selected = board.placedSelection
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(spacing: SuiteSpacing.s) {
                Button("Place…", action: choose)
                    .disabled(PlacePanel.unbuiltHelp != nil)
                    .help(PlacePanel.unbuiltHelp ?? "Choose an image to place.")
                    .suiteControl(id: "suite.place.choose", enabled: PlacePanel.unbuiltHelp == nil, reason: PlacePanel.unbuiltHelp)
                ForEach(GalleryPlaceImage.samples, id: \.name) { sample in
                    Button(sample.label) { apply(.place(name: sample.name, data: sample.data, at: nil)) }
                        .suiteControl(id: "suite.place.sample.\(sample.format.rawValue)", enabled: true, reason: nil)
                }
            }
            GalleryPlaceCanvas(drawn: board.drawn, selected: selected?.asset, selectedImage: selected?.image)
                .gesture(DragGesture(minimumDistance: 1)
                    .onChanged(dragged)
                    .onEnded { _ in
                        drag = nil
                        board.endDrag()
                    })
                .placeDropTarget(formats: Set(PlacedFormat.allCases)) { files, point in
                    let scale = GalleryPlaceImage.scale
                    for file in files { apply(.place(name: file.name, data: file.data, at: Point(x: point.x / scale, y: point.y / scale))) }
                    return true
                } onRefuse: { why in
                    refused = why
                    send("drop refused: \(why)")
                }
            if let refused {
                Text(refused).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
                    .accessibilityIdentifier("suite.place.refused")
            }
            if let selected {
                PlacedImageRows(asset: selected.asset, formats: Set(PlacedFormat.allCases), onIntent: apply)
                    .frame(width: SuiteSize.inspectorWidth.ideal)
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(log.joined(separator: "\n"))
                .accessibilityValue(log.joined(separator: "\n"))
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func choose() {
        Task { @MainActor in
            for file in await PlacePanel.choose(formats: Set(PlacedFormat.allCases)) {
                apply(.place(name: file.name, data: file.data, at: nil))
            }
        }
    }

    /// A canvas drag: its first change grabs the selected image's edge, or (⌥) its inside; every change after that
    /// resizes the box or moves the picture under the drag's token, so the whole drag is one step.
    private func dragged(_ value: DragGesture.Value) {
        let scale = GalleryPlaceImage.scale
        if drag == nil, let image = board.placedSelection?.image {
            let start = Point(x: value.startLocation.x / scale, y: value.startLocation.y / scale)
            let grab = GalleryPlaceBoard.grab(image, at: start, option: NSEvent.modifierFlags.contains(.option))
            drag = grab.map { GalleryPlaceDrag(token: UUID().uuidString, grab: $0, start: image) }
        }
        guard let drag else { return }
        let delta = Point(x: value.translation.width / scale, y: value.translation.height / scale)
        switch drag.grab {
        case .edge: send(board.resize(drag.start, right: drag.start.box.maxX + delta.x, drag: drag.token))
        case .focus: send(board.moveFocus(drag.start, by: delta, drag: drag.token))
        }
    }

    /// `intent` through the board's catalog, then its log line.
    private func apply(_ intent: PlaceIntent) {
        refused = nil
        send(board.run(intent))
    }

    private func send(_ line: String) {
        log.append(line)
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}

/// The canvas at half size: empty with its prompt, or every placed image through `drawPlaced`.
private struct GalleryPlaceCanvas: View {
    let drawn: [(asset: PlacedAsset, image: PlacedImage)]
    let selected: PlacedAsset?
    let selectedImage: PlacedImage?
    @State private var hoveredHandle: EditorHandle?

    var body: some View {
        let canvas = GalleryPlaceImage.canvas, scale = GalleryPlaceImage.scale
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SuiteColor.panel))
            for placed in drawn { context.drawPlaced(placed.asset, placed.image, scale: scale) }
        }
        .frame(width: canvas.width * scale, height: canvas.height * scale)
        .overlay {
            if drawn.isEmpty {
                Text("Drop an image here, or choose Place…").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
            }
        }
        .clipShape(.rect(cornerRadius: SuiteRadius.medium))
        .overlay(alignment: .topLeading) {
            if let image = selectedImage { selection(image) }
        }
        .contentShape(.rect)
        .help(selectedImage == nil ? "" : "Drag the right edge to resize the box; ⌥-drag inside to move the picture in it.")
        .accessibilityElement()
        .accessibilityLabel(selected == nil ? "Empty canvas" : "Image")
        .accessibilityValue(selected.map(PlacedImageText.spoken) ?? "")
        .accessibilityIdentifier("suite.place.canvas")
    }

    /// The selected image's outline and right-edge handle, and the resize pointer over the band a drag grabs.
    private func selection(_ image: PlacedImage) -> some View {
        let middle = (image.box.minY + image.box.maxY) / 2
        let edge = Rect(minX: image.box.maxX, minY: middle, maxX: image.box.maxX, maxY: middle)
        let strip = GalleryPlaceImage.edgeStrip(image)
        return ZStack(alignment: .topLeading) {
            SelectionHandles(
                box: image.box, handles: [.right: edge], zoom: GalleryPlaceImage.scale, hovered: hoveredHandle,
                onHover: { hoveredHandle = $0 })
            Color.clear
                .frame(width: strip.width, height: strip.height)
                .contentShape(.rect)
                .pointerStyle(.frameResize(position: .trailing, directions: .all))
                .offset(x: strip.minX, y: strip.minY)
                .accessibilityHidden(true)
        }
    }
}
