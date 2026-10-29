// DocumentReadCommands.swift: the two looks an agent takes at an open document, registered with one line,
// `+ DocumentReadCommands.specs(<X>Workspace.self)`. `document.read` lists the canvas size and the layers
// top-first (id, name, kind, box, hidden, opacity) with the selected ids; `view.snapshot` hands back a
// downscaled composite as base64 PNG, of the whole canvas or one region. Both are queries: no undo step,
// no change. The app draws the snapshot; the kernel only checks the params and frames the result.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An open document as an agent reads it: the canvas, the layers top-first and which are selected.
public struct DocumentOutline: Codable, Hashable, Sendable {
    /// One layer: its id and name, its kind in the app's words ("pixels", "text", "adjustment"), where it sits on the
    /// canvas (nil for a layer with no box, such as an adjustment), and whether it is hidden and how opaque.
    public struct Layer: Codable, Hashable, Sendable {
        public var id, name, kind: String; public var box: Rect?; public var hidden: Bool; public var opacity: Double
        public init(id: String, name: String, kind: String, box: Rect?, hidden: Bool, opacity: Double) {
            (self.id, self.name, self.kind, self.box, self.hidden, self.opacity) = (id, name, kind, box, hidden, opacity)
        }
    }
    public var width, height: Double; public var layers: [Layer]; public var selected: [String]
    public init(width: Double, height: Double, layers: [Layer], selected: [String]) {
        (self.width, self.height, self.layers, self.selected) = (width, height, layers, selected)
    }
}

/// A document an agent can read and look at.
public protocol DocumentReading: Sendable {
    /// The outline, nil with no document open.
    var documentOutline: DocumentOutline? { get }
    /// The composite of `region` (the whole canvas when nil), scaled so its longer side is at most `maxSide`, as PNG
    /// bytes and their pixel size. Throws when nothing is open or the region misses the canvas.
    func snapshotPNG(maxSide: Int, region: Rect?) throws -> (png: Data, width: Int, height: Int)
}

public enum DocumentReadCommands {
    static let noDocumentHelp = "Open a document first."
    /// The largest snapshot side: big enough to see, small enough for a model's context.
    public static let maxSide = 2048

    struct Empty: Codable, Sendable {}
    struct SnapshotParams: Codable, Sendable { var maxSide: Int; var region: Rect? }

    static let box = ParamSchema.object(["minX": .number(), "minY": .number(), "maxX": .number(), "maxY": .number()],
                                        required: ["minX", "minY", "maxX", "maxY"], description: "A box in canvas pixels.")
    static let outline = ParamSchema.object(
        ["width": .number("Canvas width in pixels."), "height": .number("Canvas height in pixels."),
         "layers": .array(of: .object(
            ["id": .string(), "name": .string(), "kind": .string("The layer's kind in the app's words."),
             "box": .optional(box), "hidden": .boolean, "opacity": .number("0 to 1.", minimum: 0, maximum: 1)],
            required: ["id", "name", "kind", "hidden", "opacity"])),
         "selected": .array(of: .string("A selected layer's id."))],
        required: ["width", "height", "layers", "selected"])
    static let snapshotSchema = ParamSchema.object(
        ["maxSide": .integer("The snapshot's longer side at most, in pixels.", minimum: 16, maximum: maxSide),
         "region": .optional(box)], required: ["maxSide"])
    static let snapshot = ParamSchema.object(
        ["png": .string("The PNG, base64."), "width": .integer(minimum: 1), "height": .integer(minimum: 1)],
        required: ["png", "width", "height"])

    /// `document.read` and `view.snapshot` on `target`, both queries.
    public static func specs<T: DocumentReading>(_ target: T.Type) -> [CommandSpec<T>] {
        let open: @Sendable (T) -> Availability = { $0.documentOutline == nil ? .unavailable(noDocumentHelp) : .available }
        return [
            .typed("document.read", title: "Read Document", summary: "Reads the canvas size, the layers top-first with id, name, kind, box, hidden and opacity, and the selected layer ids.",
                   kind: .query, params: Empty.self, schema: .none, result: outline, example: .object([:]), availability: open) { doc, _ in
                guard let outline = doc.documentOutline else { throw CatalogError.unavailable(id: "document.read", why: noDocumentHelp) }
                return outline
            },
            .typed("view.snapshot", title: "Snapshot", summary: "Returns the composite, or one region of it, downscaled to a longest side, as base64 PNG; changes nothing.",
                   kind: .query, params: SnapshotParams.self, schema: snapshotSchema, result: snapshot,
                   example: .object(["maxSide": .number(256)]), availability: open) { doc, p in
                let shot = try doc.snapshotPNG(maxSide: min(max(p.maxSide, 16), maxSide), region: p.region)
                return JSONValue.object(["png": .string(shot.png.base64EncodedString()),
                                         "width": .number(Double(shot.width)), "height": .number(Double(shot.height))])
            },
        ]
    }

    /// The pixel size `width` × `height` scales to so its longer side is at most `maxSide`, never upscaled.
    public static func fitted(width: Int, height: Int, maxSide: Int) -> (width: Int, height: Int) {
        let longest = max(width, height)
        guard longest > maxSide, longest > 0 else { return (width, height) }
        let scale = Double(maxSide) / Double(longest)
        return (max(Int((Double(width) * scale).rounded()), 1), max(Int((Double(height) * scale).rounded()), 1))
    }
}
