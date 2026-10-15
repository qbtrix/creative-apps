// Live/NotBuilt.swift: the stand-ins `.live` holds for a use case whose
// feature hasn't landed. Every call refuses with the same text its
// `unavailableHelp` gives, so a control that reaches one anyway shows why.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

struct NotBuilt: Sendable {
    let feature: String
    var help: String { "Not built yet (\(feature))." }
    func refuse() -> PhotoRefusal { PhotoRefusal(help) }
}

struct NotBuiltArchive: DocumentArchiving {
    let not = NotBuilt(feature: "PV-1")
    var unavailableHelp: String? { not.help }
    var formatVersion: Int { 0 }
    func encode(_ snapshot: PhotoDocumentSnapshot, codec: any PhotoImageCodec) throws -> PhotoPackage { throw not.refuse() }
    func decode(_ package: PhotoPackage, codec: any PhotoImageCodec) throws -> PhotoDocumentSnapshot { throw not.refuse() }
    func container(_ package: PhotoPackage) throws -> Data { throw not.refuse() }
    func package(fromContainer data: Data) throws -> PhotoPackage { throw not.refuse() }
}

struct NotBuiltRecovery: RecoveryStoring {
    let not = NotBuilt(feature: "PV-1")
    var unavailableHelp: String? { not.help }
    func write(_ entry: RecoveryEntry, window: String) throws { throw not.refuse() }
    func leftBehind() throws -> [RecoveryEntry] { [] }
    func discard(window: String) throws {}
    func discardAll() throws {}
}

struct NotBuiltClipboard: PixelClipboard {
    let not = NotBuilt(feature: "PV-2")
    var unavailableHelp: String? { not.help }
    func copy(_ content: PlacedPixels, selection: PixelRect?, mask: Mask?) throws -> ClipboardImage? { throw not.refuse() }
    func placement(of image: ClipboardImage, canvas: CanvasSize, center: Mask.Point) -> PixelRect {
        PixelRect(x: 0, y: 0, width: image.image.width, height: image.image.height)
    }
}

struct NotBuiltMerging: LayerMerging {
    let not = NotBuilt(feature: "PV-2")
    var unavailableHelp: String? { not.help }
    func mergeDown(_ upper: LayerContent, onto lower: LayerContent) throws -> PlacedPixels { throw not.refuse() }
    func flatten(_ layers: [LayerContent], canvas: CanvasSize, adjustments: AdjustmentSettings) throws -> TiledPixels {
        throw not.refuse()
    }
}

struct NotBuiltSelection: SelectionShaping {
    let not = NotBuilt(feature: "PV-5")
    var unavailableHelp: String? { not.help }
    func mask(for shape: SelectionShape, canvas: CanvasSize) throws -> Mask { throw not.refuse() }
    func combine(_ current: Mask?, with new: Mask, _ mode: SelectionCombine) throws -> Mask? { throw not.refuse() }
    func inverted(_ mask: Mask?, canvas: CanvasSize) throws -> Mask? { throw not.refuse() }
    func feathered(_ mask: Mask, radius: Double) throws -> Mask { throw not.refuse() }
    func bounds(of mask: Mask) -> PixelRect? { nil }
    func outline(of mask: Mask) -> [[Mask.Point]] { [] }
}

struct NotBuiltMasking: LayerMasking {
    let not = NotBuilt(feature: "PV-5")
    var unavailableHelp: String? { not.help }
    func mask(from selection: Mask?, layerBounds: PixelRect) throws -> TiledPixels { throw not.refuse() }
    func applying(_ mask: TiledPixels, to pixels: TiledPixels) throws -> TiledPixels { throw not.refuse() }
    func masked(_ region: PixelBuffer, at origin: (x: Int, y: Int), by mask: TiledPixels) throws -> PixelBuffer { region }
}

struct NotBuiltAdjustmentLayers: AdjustmentLayering {
    let not = NotBuilt(feature: "PV-6")
    var unavailableHelp: String? { not.help }
    var kinds: [AdjustmentKind] { [] }
    func applying(_ settings: AdjustmentSettings, to below: PixelBuffer, opacity: Double, blendMode: BlendMode,
                  mask: PixelBuffer?) throws -> PixelBuffer { below }
}

struct NotBuiltTransform: LayerTransforming {
    let not = NotBuilt(feature: "PV-7")
    var unavailableHelp: String? { not.help }
    func handle(at point: Mask.Point, in draft: TransformDraft, tolerance: Double) -> TransformHandle? { nil }
    func dragged(_ draft: TransformDraft, handle: TransformHandle, from start: Mask.Point, to point: Mask.Point,
                 modifiers: DragModifiers) -> TransformDraft { draft }
    func corners(of draft: TransformDraft) -> [Mask.Point] { [] }
    func applied(_ draft: TransformDraft, to content: PlacedPixels) throws -> PlacedPixels { throw not.refuse() }
    func flipped(_ content: PlacedPixels, _ axis: FlipAxis) throws -> PlacedPixels { throw not.refuse() }
}

struct NotBuiltExportSizing: ExportSizing {
    let not = NotBuilt(feature: "PV-8")
    var unavailableHelp: String? { not.help }
    func outputSize(for canvas: CanvasSize, _ size: ExportSize) throws -> CanvasSize { canvas }
    func resized(_ image: DecodedImage, to size: CanvasSize) throws -> DecodedImage { image }
}

struct NotBuiltSampling: ColorSampling {
    let not = NotBuilt(feature: "PV-9")
    var unavailableHelp: String? { not.help }
    func sample(_ picture: PixelBuffer, center: (x: Int, y: Int), size: SampleSize) -> SampledColor? { nil }
}
