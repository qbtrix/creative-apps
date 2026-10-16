// FakePasteboard.swift: the reference PasteboardCoding (UC-7), pure. Each app
// takes the richest representation it accepts: a damaged envelope falls back
// to SVG, then PNG, then text. A dropped file URL becomes a ref with the one
// identity rule, `SuiteDocumentRef.fileID(forPath:)` (packet correction 3),
// so it dedupes against its recents entry. Pure, so it takes no
// `unavailable:` (packet correction 6).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct FakePasteboard: PasteboardCoding {
    public init() {}

    /// What each app can take, best first.
    public static let accepts: [SuiteApp: [SuiteTypeID]] = [
        .flare: [.assetEnvelope, .flareLayers, .svg, .plainText, .fileURL],
        .design: [.assetEnvelope, .designLayers, .svg, .png, .plainText, .fileURL],
        .photo: [.assetEnvelope, .png, .jpeg, .heic, .plainText, .fileURL],
        .library: [.png, .jpeg, .heic, .fileURL],
        .halo: [.assetEnvelope, .plainText, .fileURL],
        .launcher: [.fileURL, .assetEnvelope, .svg, .png],
    ]

    public func representations(of item: SuiteClipItem) -> [TypedData] {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        switch item {
        case .envelope(let e):
            var reps = [TypedData]()
            if let d = try? enc.encode(e) { reps.append(TypedData(type: .assetEnvelope, data: d)) }
            if let svg = e.svg { reps.append(TypedData(type: .svg, data: Data(svg.utf8))) }
            if let c = e.color { reps.append(TypedData(type: .plainText, data: Data(("#" + c.hex).utf8))) }
            return reps
        case .vector(let svg, _): return [TypedData(type: .svg, data: Data(svg.utf8))]
        case .image(let png, _, _): return [TypedData(type: .png, data: png)]
        case .color(let c):
            let e = AssetEnvelope(name: "#" + c.hex, kind: .color, from: .launcher, color: c)
            return representations(of: .envelope(e))
        case .text(let t): return [TypedData(type: .plainText, data: Data(t.utf8))]
        case .files(let refs): return refs.map { TypedData(type: .fileURL, data: Data(("file://" + $0.path).utf8)) }
        }
    }

    public func bestItem(from offered: [TypedData], for app: SuiteApp) -> SuiteClipItem? {
        for type in Self.accepts[app] ?? [] {
            guard let rep = offered.first(where: { $0.type == type }) else { continue }
            switch type {
            case .assetEnvelope:
                guard let e = try? JSONDecoder().decode(AssetEnvelope.self, from: rep.data) else { continue }   // damaged: fall back
                if e.kind == .image, app == .flare || app == .halo { continue }
                return .envelope(e)
            case .svg: return .vector(svg: String(decoding: rep.data, as: UTF8.self), name: "Pasted art")
            case .png, .jpeg, .heic: return .image(png: rep.data, pixelWidth: 0, pixelHeight: 0)
            case .plainText: return .text(String(decoding: rep.data, as: UTF8.self))
            case .fileURL:
                let refs = offered.filter { $0.type == .fileURL }.compactMap(fileRef)
                if refs.isEmpty { continue }
                return .files(refs)
            default: continue   // an app's own layer types are read by that app's model, not here
            }
        }
        return nil
    }

    public func pasteRefusal(for offered: [TypedData], in app: SuiteApp) -> SuiteError? {
        if offered.isEmpty { return .nothingToPaste }
        if bestItem(from: offered, for: app) != nil { return nil }
        if offered.contains(where: { [.png, .jpeg, .heic].contains($0.type) }) { return .cannotPaste(app: app, kind: "images") }
        return .cannotPaste(app: app, kind: "this")
    }

    /// A `file://<path>` representation as a ref routed to its default app, or nil.
    func fileRef(_ rep: TypedData) -> SuiteDocumentRef? {
        let url = String(decoding: rep.data, as: UTF8.self)
        guard url.hasPrefix("file://") else { return nil }
        let path = String(url.dropFirst("file://".count))
        let name = path.split(separator: "/").last.map(String.init) ?? path
        let routing = FakeRouting()
        guard let target = try? routing.route(fileName: name),
              let type = routing.registry.type(forExtension: name.split(separator: ".").last.map(String.init) ?? "")
        else { return nil }
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: target,
                                type: type.id, displayName: name)
    }
}
