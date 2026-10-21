// CopyAsCommands.swift (clipboard-interop CB-1): Copy As, Paste as Image and Copy Frame as catalog specs with real
// ids, schemas and availability. An app registers them with `+ CopyAsCommands.specs(<X>Workspace.self)` (and Halo
// `+ CopyAsCommands.frameSpecs(...)`) once its pasteboard adapter conforms; the bytes go to the pasteboard
// through SuiteModel's coder, which the app's adapter calls.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What Copy As writes: a PNG of the selection, an SVG of it, or the app's own layer bytes.
public enum CopyAsFormat: String, Codable, Sendable, CaseIterable { case png, svg, own }

/// The bytes one copy makes and the pasteboard type id they go under ("public.png").
public struct CopiedBytes: Hashable, Sendable {
    public var type: String
    public var data: Data
    public init(type: String, data: Data) { (self.type, self.data) = (type, data) }
}

/// A document Copy As and Paste as Image act on: an app's workspace conforms in its pasteboard adapter.
public protocol CopyAsTarget: Sendable {
    /// Why nothing can be copied now (no selection); nil when Copy As can run.
    var copyAsHelp: String? { get }
    /// Why Paste as Image can't run (no document, no image offered); nil when it can.
    var pasteAsImageHelp: String? { get }
    /// The selection's bytes in `format`; throws the sentence when this app can't make that format.
    func copyAs(_ format: CopyAsFormat) throws -> CopiedBytes
    /// Places an image file's bytes as a picture, one undo step.
    mutating func pasteAsImage(name: String, data: Data) throws
}

/// A document with a viewer frame Copy Frame writes as PNG (Halo).
public protocol CopyFrameTarget: Sendable {
    /// Why the frame can't be copied now; nil when it can.
    var copyFrameHelp: String? { get }
    /// The viewer's frame at the playhead as PNG bytes, at the composition's size.
    func copyFrame() throws -> Data
}

/// The Copy As, Paste as Image and Copy Frame specs.
public enum CopyAsCommands {
    struct FormatParams: Codable, Sendable { var format: CopyAsFormat }
    struct ImageParams: Codable, Sendable { var name, base64: String }
    struct Empty: Codable, Sendable {}
    /// What a copy returns: its type id and its bytes in base64.
    struct Copied: Encodable { var type, base64: String }

    static let format = ParamSchema.string("png, svg, or own: the app's own layers.", oneOf: CopyAsFormat.allCases.map(\.rawValue))
    static let copied = ParamSchema.object(["type": .string("The pasteboard type id, \"public.png\"."),
                                            "base64": .string("The copied bytes, base64.")], required: ["type", "base64"])
    static let image = ParamSchema.object(["name": .string("The file name, \"screenshot.png\".", maxLength: 255),
                                           "base64": .string("The file's bytes, base64: PNG, TIFF, JPEG, HEIC or SVG.")],
                                          required: ["name", "base64"])
    /// A 1 × 1 PNG's signature: the example every fixture can be offered.
    static let example: JSONValue = .object(["name": .string("pasted.png"),
                                             "base64": .string(Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString())])

    /// `edit.copy-as` (a query: it writes the pasteboard, not the document) and `edit.paste-as-image` (one undo step).
    public static func specs<T: CopyAsTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("edit.copy-as", title: "Copy As", summary: "Copies the selection as PNG, SVG or this app's own layers; returns the type and bytes.",
                   kind: .query, params: FormatParams.self, schema: .object(["format": format], required: ["format"]), result: copied,
                   example: .object(["format": .string("png")]), availability: { help($0.copyAsHelp) }) { t, p in
                let bytes = try t.copyAs(p.format)
                return Copied(type: bytes.type, base64: bytes.data.base64EncodedString())
            },
            .typed("edit.paste-as-image", title: "Paste as Image", summary: "Pastes an image or SVG file as a placed picture, one undo step.",
                   kind: .edit, params: ImageParams.self, schema: image, example: example,
                   availability: { help($0.pasteAsImageHelp) }) { t, p -> JSONValue in
                guard let data = Data(base64Encoded: p.base64) else {
                    throw CatalogError.failed(id: "edit.paste-as-image", message: "\(p.name) isn't base64.")
                }
                try t.pasteAsImage(name: p.name, data: data)
                return .object([:])
            },
        ]
    }

    /// `edit.copy-frame`: the viewer's frame as PNG.
    public static func frameSpecs<T: CopyFrameTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("edit.copy-frame", title: "Copy Frame", summary: "Copies the viewer's frame at the playhead as a PNG at the composition's size.",
                   kind: .query, params: Empty.self, schema: ParamSchema.none, result: copied, example: .object([:]),
                   availability: { help($0.copyFrameHelp) }) { t, _ in
                Copied(type: "public.png", base64: try t.copyFrame().base64EncodedString())
            },
        ]
    }

    /// A help sentence as availability: nil is available.
    static func help(_ why: String?) -> Availability { why.map(Availability.unavailable) ?? .available }
}
