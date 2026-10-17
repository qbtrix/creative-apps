// FakeAssets.swift: the in-memory AssetLibrary (UC-8). Adds and updates go
// through `AssetIndex.add(_:)` and `update(_:at:color:payload:)`, so the
// revision rule lives in one place; payloads sit at
// `assets/<id>/<revision>.<ext>`. Every index change streams its revision
// through `ChangeFeed`. With `unavailable:` set, every throwing call throws
// `.notAvailable(that sentence)`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public actor FakeAssets: AssetLibrary {
    public private(set) var stored: AssetIndex {
        didSet { if stored.revision != oldValue.revision { feed.send(stored.revision) } }
    }
    var feed = ChangeFeed()
    var payloads: [String: Data] = [:]
    let unavailable: String?
    public init(_ index: AssetIndex = AssetIndex(), unavailable: String? = nil) { stored = index; self.unavailable = unavailable }

    public func index() throws(SuiteError) -> AssetIndex { if let unavailable { throw .notAvailable(unavailable) }; return stored }

    public func add(_ draft: AssetDraft, id: String, at date: Date) throws(SuiteError) -> SuiteAsset {
        if let unavailable { throw .notAvailable(unavailable) }
        let path = draft.payload == nil ? nil : "assets/\(id)/1.\(draft.payloadExtension ?? "bin")"
        let a = SuiteAsset(id: id, kind: draft.kind, name: draft.name, color: draft.color, payload: path,
                           source: draft.source, modifiedAt: date)
        if let path, let d = draft.payload { payloads[path] = d }
        stored.add(a)
        return a
    }

    public func update(_ id: String, payload: Data?, color: SuiteColorValue?, at date: Date) throws(SuiteError) -> SuiteAsset {
        if let unavailable { throw .notAvailable(unavailable) }
        guard let old = stored.asset(id) else { throw .notAvailable("This asset was removed.") }
        var path: String?
        if let payload, let oldPath = old.payload {
            let ext = oldPath.split(separator: ".").last.map(String.init) ?? "bin"
            let next = "assets/\(id)/\(old.revision + 1).\(ext)"
            payloads[next] = payload
            path = next
        }
        guard let a = stored.update(id, at: date, color: color, payload: path) else {
            throw .notAvailable("This asset was removed.")
        }
        return a
    }

    public func remove(_ id: String) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        var next = stored
        next.assets.removeAll { $0.id == id }
        next.revision += 1
        stored = next
    }

    public func payload(of asset: SuiteAsset) throws(SuiteError) -> Data {
        if let unavailable { throw .notAvailable(unavailable) }
        guard let p = asset.payload, let d = payloads[p] else { throw .fileMissing(name: asset.name) }
        return d
    }

    public func assets(fromFileID fileID: String) throws(SuiteError) -> [SuiteAsset] {
        if let unavailable { throw .notAvailable(unavailable) }
        return stored.assets.filter { $0.source?.fileID == fileID }
    }

    public func changes() -> AsyncStream<Int> { feed.stream() }
}
