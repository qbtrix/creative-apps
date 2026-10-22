// CropCommands.swift (orientation-crop OC-a shape and bodies, OC-m rules): the image.rotate-*,
// image.flip and crop.* commands any app with an OrientationTarget and a CropTarget registers. Ids,
// titles, schemas and availability are the contract; each edit applies one rule and sets once.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What an app gives the crop commands: why it can't crop, the pending frame and its bounds, and
/// the edits that record named undo steps.
public protocol CropTarget: Sendable {
    /// Why the image can't be cropped, in the app's words; nil when it can.
    var cropHelp: String? { get }
    /// The pending crop; nil when there is none.
    var cropFrame: CropFrame? { get }
    /// The space a frame lies in: the oriented image's pixels, or the unit square.
    var cropBounds: Rect { get }
    /// Sets (or, with nil, drops) the pending crop as one undo step named `name`.
    mutating func setCropFrame(_ f: CropFrame?, name: String) throws
    /// Crops the image to the pending frame as one undo step.
    mutating func applyCrop() throws
}

/// The image and crop specs, and their params.
public enum CropCommands {
    /// Commands that take nothing.
    public struct NoParams: Codable, Sendable {}
    /// `image.flip`: mirror across `axis`.
    public struct FlipParams: Codable, Sendable { public var axis: FlipDirection }
    /// `crop.set-aspect`: "Free", "Original" or "W:H", standing `orientation` (the image's way when nil).
    public struct AspectParams: Codable, Sendable { public var aspect: String; public var orientation: CropOrientation? }
    /// `crop.set-frame`: the frame's rect in the bounds' space and its straighten angle.
    public struct FrameParams: Codable, Sendable { public var x, y, w, h: Double; public var angle: Double? }
    /// The image commands' result: the EXIF number the image now faces.
    public struct Facing: Codable, Sendable { public var orientation: Int }
    /// The crop commands' result: the pending frame, or null when there is none.
    public struct Frame: Codable, Sendable { public var x, y, w, h, angle: Double }

    static let facingSchema = ParamSchema.object(["orientation": .integer("EXIF orientation, 1 to 8.", minimum: 1, maximum: 8)],
                                                 required: ["orientation"])
    static let frameSchema = ParamSchema.object(
        ["x": .number("Left."), "y": .number("Top."), "w": .number("Width."), "h": .number("Height."), "angle": .number("Straighten, degrees.")],
        required: ["x", "y", "w", "h", "angle"])

    /// The four image specs: rotate right, left and half a turn, and flip.
    public static func orientationSpecs<T: OrientationTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        let can: @Sendable (T) -> Availability = { $0.orientationHelp.map(Availability.unavailable) ?? .available }
        let turns: [(String, String, String, @Sendable (Orientation) -> Orientation)] = [
            ("image.rotate-cw", "Rotate Right", "Turns the image a quarter clockwise.", { $0.rotated(clockwise: true) }),
            ("image.rotate-ccw", "Rotate Left", "Turns the image a quarter counter-clockwise.", { $0.rotated(clockwise: false) }),
            ("image.rotate-180", "Rotate 180°", "Turns the image half a turn.", { $0.rotated(clockwise: true).rotated(clockwise: true) }),
        ]
        return turns.map { id, title, summary, turn in
            .typed(id, title: title, summary: summary, kind: .edit, params: NoParams.self, schema: .none, result: facingSchema,
                   example: .object([:]), availability: can) { (t: inout T, _: NoParams) throws -> Facing in
                try face(&t, turn(t.orientation), name: title)
            }
        } + [
            .typed("image.flip", title: "Flip", summary: "Mirrors the image: Flip Horizontal or Flip Vertical.", kind: .edit,
                   params: FlipParams.self,
                   schema: .object(["axis": .string("Which way to mirror.", oneOf: FlipDirection.allCases.map(\.rawValue))], required: ["axis"]),
                   result: facingSchema, example: .object(["axis": .string("horizontal")]),
                   availability: can) { (t: inout T, p: FlipParams) throws -> Facing in
                try face(&t, t.orientation.flipped(p.axis), name: p.axis == .horizontal ? "Flip Horizontal" : "Flip Vertical")
            },
        ]
    }

    /// The five crop specs: set the aspect, swap, set the frame, apply and reset.
    public static func cropSpecs<T: CropTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        let can: @Sendable (T) -> Availability = { $0.cropHelp.map(Availability.unavailable) ?? .available }
        return [
            .typed("crop.set-aspect", title: "Crop Ratio", summary: "Locks the crop to a ratio and frames the largest centred crop of it.",
                   kind: .edit, params: AspectParams.self,
                   schema: .object(["aspect": .string("Free, Original or W:H, as 4:5.", maxLength: 16),
                                    "orientation": .optional(.string("Which way the ratio stands; the image's way when left out.",
                                                                     oneOf: CropOrientation.allCases.map(\.rawValue)))],
                                   required: ["aspect", "orientation"]),
                   result: frameSchema, example: .object(["aspect": .string("4:5"), "orientation": .string("portrait")]),
                   availability: can) { (t: inout T, p: AspectParams) throws -> Frame? in
                guard let aspect = CropAspect(rawValue: p.aspect) else {
                    throw CatalogError.failed(id: "crop.set-aspect", message: "\(p.aspect) is not Free, Original or W:H.")
                }
                let rect = CropRules.largest(aspect, orientation: p.orientation, in: t.cropBounds)
                return try commit(&t, rect, name: "Crop Ratio")
            },
            .typed("crop.swap", title: "Swap Crop", summary: "Turns the crop between landscape and portrait about its centre.",
                   kind: .edit, params: NoParams.self, schema: .none, result: frameSchema, example: .object([:]),
                   availability: can) { (t: inout T, _: NoParams) throws -> Frame? in
                try commit(&t, CropRules.swapped(try pending(t, "crop.swap").rect, in: t.cropBounds), name: "Swap Crop")
            },
            .typed("crop.set-frame", title: "Crop Frame", summary: "Sets the crop's rect and straighten angle.", kind: .edit,
                   params: FrameParams.self,
                   schema: .object(["x": .number("Left."), "y": .number("Top."), "w": .number("Width, above 0."), "h": .number("Height, above 0."),
                                    "angle": .optional(.number("Straighten, degrees.", minimum: -45, maximum: 45))],
                                   required: ["x", "y", "w", "h", "angle"]),
                   result: frameSchema, example: .object(["x": .number(0), "y": .number(0), "w": .number(1), "h": .number(1)]),
                   availability: can) { (t: inout T, p: FrameParams) throws -> Frame? in try setFrame(&t, p) },
            .typed("crop.apply", title: "Crop", summary: "Crops the image to the pending frame.", kind: .edit, params: NoParams.self,
                   schema: .none, result: frameSchema, example: .object([:]), availability: can) { (t: inout T, _: NoParams) throws -> Frame? in
                let frame = try pending(t, "crop.apply")
                try t.applyCrop()
                return reading(frame)
            },
            .typed("crop.reset", title: "Reset Crop", summary: "Drops the pending crop.", kind: .edit, params: NoParams.self,
                   schema: .none, result: .none, example: .object([:]), availability: can) { (t: inout T, _: NoParams) throws -> Frame? in
                try t.setCropFrame(nil, name: "Reset Crop")
                return nil
            },
        ]
    }

    /// All nine specs, for an app whose document turns and crops.
    public static func specs<T: OrientationTarget & CropTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        orientationSpecs(target) + cropSpecs(target)
    }

    static func face<T: OrientationTarget>(_ t: inout T, _ o: Orientation, name: String) throws -> Facing {
        try t.setOrientation(o, name: name)
        return Facing(orientation: o.rawValue)
    }

    /// The pending frame, or `failed` for `id` when there is none.
    static func pending<T: CropTarget>(_ t: T, _ id: String) throws -> CropFrame {
        guard let f = t.cropFrame else { throw CatalogError.failed(id: id, message: "Drag on the image, or pick a ratio, to start a crop.") }
        return f
    }

    static func commit<T: CropTarget>(_ t: inout T, _ rect: Rect, name: String) throws -> Frame? {
        let frame = CropFrame(rect: rect, angle: t.cropFrame?.angle ?? 0)
        try t.setCropFrame(frame, name: name)
        return reading(frame)
    }

    /// `crop.set-frame`: a rect with both sides above 0 inside the bounds; anything else throws.
    static func setFrame<T: CropTarget>(_ t: inout T, _ p: FrameParams) throws -> Frame? {
        let b = t.cropBounds, rect = Rect(minX: p.x, minY: p.y, maxX: p.x + p.w, maxY: p.y + p.h)
        guard p.w > 0, p.h > 0, rect.minX >= b.minX, rect.minY >= b.minY, rect.maxX <= b.maxX, rect.maxY <= b.maxY else {
            throw CatalogError.failed(id: "crop.set-frame", message: "The frame must have width and height and lie inside the image.")
        }
        let frame = CropFrame(rect: rect, angle: p.angle ?? t.cropFrame?.angle ?? 0)
        try t.setCropFrame(frame, name: "Crop Frame")
        return reading(frame)
    }

    static func reading(_ f: CropFrame) -> Frame {
        Frame(x: f.rect.minX, y: f.rect.minY, w: f.rect.width, h: f.rect.height, angle: f.angle)
    }
}
