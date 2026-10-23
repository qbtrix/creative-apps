// PresetStore.swift: saved presets (looks first) shared by every app
// (adjust-everywhere AJ-2 stubs, AJ-7 body). `PresetStoring` is the
// contract; `PresetStore` keeps them in FileStore's revisioned
// `presets/looks.json`, names unique ignoring case. Until AJ-7 every save
// and delete refuses with the same text a control's help gives, the
// NotBuilt shape PhotoModel's stand-ins use, and `list` is empty.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The saved presets of each kind.
public protocol PresetStoring: Sendable {
    func list(kind: String) -> [PresetRecord]
    /// Refuses a name another preset of the kind already has, ignoring case.
    func save(_ r: PresetRecord) throws(SuiteError)
    func delete(id: String, kind: String) throws(SuiteError)
}

/// One saved preset: its kind (`look`, ...) and the kind's own encoded value.
public struct PresetRecord: Hashable, Codable, Sendable {
    public var id, name, kind: String
    public var payload: Data

    public init(id: String, name: String, kind: String, payload: Data) {
        self.id = id
        self.name = name
        self.kind = kind
        self.payload = payload
    }
}

/// The live PresetStoring over FileStore's presets/looks.json.
public struct PresetStore: PresetStoring {
    public static let file = "presets/looks.json"
    let store: FileStore
    private let not = NotBuilt(feature: "AJ-7")

    public init(folder: String) {
        store = FileStore(folder: folder)
    }

    public func list(kind: String) -> [PresetRecord] { [] }
    public func save(_ r: PresetRecord) throws(SuiteError) { throw not.refuse() }
    public func delete(id: String, kind: String) throws(SuiteError) { throw not.refuse() }
}

/// A use case whose feature hasn't landed: it refuses with its help text.
private struct NotBuilt: Sendable {
    let feature: String
    var help: String { "Not built yet (\(feature))." }
    func refuse() -> SuiteError { .notAvailable(help) }
}
