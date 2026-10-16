// Assets.swift: a library asset, what an app hands to Add to Assets, and
// the index every process reads, with the add, update, search and merge
// rules tested once here. Foundation only for `Data` and `Date`,
// Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One asset in the suite's library.
public struct SuiteAsset: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: AssetKind
    public var name: String
    public var revision: Int               // +1 on every update
    public var color: SuiteColorValue?     // kind == .color
    public var payload: String?            // "assets/<id>/<revision>.svg" for the other kinds
    public var source: SuiteDocumentRef?   // where it was added from, if anywhere
    public var modifiedAt: Date
    public init(id: String, kind: AssetKind, name: String, revision: Int = 1, color: SuiteColorValue? = nil,
                payload: String? = nil, source: SuiteDocumentRef? = nil, modifiedAt: Date) {
        self.id = id; self.kind = kind; self.name = name; self.revision = revision; self.color = color
        self.payload = payload; self.source = source; self.modifiedAt = modifiedAt
    }
}

/// What an app hands to Add to Assets.
public struct AssetDraft: Equatable, Sendable {
    public var kind: AssetKind
    public var name: String
    public var color: SuiteColorValue?
    public var payload: Data?              // SVG text, PNG bytes or a .flare file's bytes
    public var payloadExtension: String?   // "svg", "png", "flare"
    public var source: SuiteDocumentRef?
    public init(kind: AssetKind, name: String, color: SuiteColorValue? = nil, payload: Data? = nil,
                payloadExtension: String? = nil, source: SuiteDocumentRef? = nil) {
        self.kind = kind; self.name = name; self.color = color; self.payload = payload
        self.payloadExtension = payloadExtension; self.source = source
    }
}

/// The library's index. Its revision moves on every add, update and remove.
public struct AssetIndex: Codable, Equatable, Sendable {
    public var revision: Int
    public var assets: [SuiteAsset]
    public init(revision: Int = 0, assets: [SuiteAsset] = []) { self.revision = revision; self.assets = assets }

    public func asset(_ id: String) -> SuiteAsset? { assets.first { $0.id == id } }

    /// Puts the asset first (replacing one with the same id) and bumps the index revision.
    public mutating func add(_ asset: SuiteAsset) {
        assets.removeAll { $0.id == asset.id }
        assets.insert(asset, at: 0)
        revision += 1
    }

    /// Bumps the asset's revision and the index's, stamps `date` and sets the
    /// colour or payload path given. Nil, and nothing moves, when the id is gone.
    @discardableResult
    public mutating func update(_ id: String, at date: Date, color: SuiteColorValue? = nil,
                                payload: String? = nil) -> SuiteAsset? {
        guard let i = assets.firstIndex(where: { $0.id == id }) else { return nil }
        var a = assets[i]
        a.revision += 1; a.modifiedAt = date
        if let color { a.color = color }
        if let payload { a.payload = payload }
        assets[i] = a
        revision += 1
        return a
    }

    /// By kind (nil: all) and name, any case, newest first.
    public func search(_ query: String, kind: AssetKind?) -> [SuiteAsset] {
        let q = query.lowercased()
        return assets
            .filter { (kind == nil || $0.kind == kind) && (q.isEmpty || $0.name.lowercased().contains(q)) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// Two writers raced: per asset keep the higher revision; removals are not resurrected
    /// because a remove bumps the index revision and the remover writes last.
    public func merging(_ other: AssetIndex) -> AssetIndex {
        var byID: [String: SuiteAsset] = [:]
        for a in assets + other.assets {
            if let have = byID[a.id], have.revision >= a.revision { continue }
            byID[a.id] = a
        }
        return AssetIndex(revision: max(revision, other.revision),
                          assets: byID.values.sorted { $0.modifiedAt > $1.modifiedAt })
    }
}
