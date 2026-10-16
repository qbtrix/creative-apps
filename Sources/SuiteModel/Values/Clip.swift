// Clip.swift: what goes on the pasteboard or in a drag, the suite's own
// asset envelope, and what a paste delivers to an app. Foundation only for
// `Data`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One representation on the pasteboard or in a drag.
public struct TypedData: Equatable, Sendable {
    public var type: SuiteTypeID
    public var data: Data
    public init(type: SuiteTypeID, data: Data) { self.type = type; self.data = data }
}

/// The suite's own envelope: what was copied, from where, and its link if it is an asset.
public struct AssetEnvelope: Codable, Equatable, Sendable {
    public var name: String
    public var kind: AssetKind
    public var from: SuiteApp
    public var link: AssetLink?
    public var color: SuiteColorValue?
    public var svg: String?
    public init(name: String, kind: AssetKind, from: SuiteApp, link: AssetLink? = nil,
                color: SuiteColorValue? = nil, svg: String? = nil) {
        self.name = name; self.kind = kind; self.from = from; self.link = link; self.color = color; self.svg = svg
    }
}

/// What a paste or drop delivers to an app, after the suite chose the best representation.
public enum SuiteClipItem: Equatable, Sendable {
    case envelope(AssetEnvelope)
    case vector(svg: String, name: String)
    case image(png: Data, pixelWidth: Int, pixelHeight: Int)
    case color(SuiteColorValue)
    case text(String)
    case files([SuiteDocumentRef])

    /// The plural the "can't paste" sentence names.
    public var kindName: String {
        switch self {
        case .envelope(let e): e.kind == .image ? "images" : e.kind == .color ? "colours" : "vector art"
        case .vector: "vector art"
        case .image: "images"
        case .color: "colours"
        case .text: "text"
        case .files: "files"
        }
    }
}
