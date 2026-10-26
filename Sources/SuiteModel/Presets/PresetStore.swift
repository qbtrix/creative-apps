// PresetStore.swift: saved presets (looks first) shared by every app
// (adjust-everywhere AJ-2 contract, AJ-7 body). `PresetStoring` is the
// contract; `PresetStore` keeps every kind's records in FileStore's
// revisioned `presets/looks.json`, so a save from one app is read by the
// next launch of any other. Saving an id already stored replaces it; a name
// another preset of the kind already has, ignoring case, is refused and
// nothing is written; deleting an id that isn't stored is refused. A file
// that can't be read lists as empty. The same rules as FakePresetStore.
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

    public init(folder: String) {
        store = FileStore(folder: folder)
    }

    public func list(kind: String) -> [PresetRecord] {
        current().filter { $0.kind == kind }
    }

    public func save(_ r: PresetRecord) throws(SuiteError) {
        if let refusal = Self.taken(r, in: current()) { throw refusal }
        var refusal: SuiteError?
        try store.update(Self.file, empty: [PresetRecord]()) { all in
            // Checked again under the lock: another app may have saved the name since.
            refusal = Self.taken(r, in: all)
            guard refusal == nil else { return all }
            var next = all
            if let i = next.firstIndex(where: { $0.kind == r.kind && $0.id == r.id }) { next[i] = r } else { next.append(r) }
            return next
        }
        if let refusal { throw refusal }
    }

    public func delete(id: String, kind: String) throws(SuiteError) {
        guard current().contains(where: { $0.kind == kind && $0.id == id }) else { throw Self.removed }
        var found = false
        try store.update(Self.file, empty: [PresetRecord]()) { all in
            found = all.contains { $0.kind == kind && $0.id == id }
            return all.filter { !($0.kind == kind && $0.id == id) }
        }
        if !found { throw Self.removed }
    }

    static let removed = SuiteError.notAvailable("This preset was removed.")

    /// The refusal for saving `r` among `all`: a name another preset of its kind has, ignoring case.
    static func taken(_ r: PresetRecord, in all: [PresetRecord]) -> SuiteError? {
        let clash = all.contains { $0.kind == r.kind && $0.id != r.id && $0.name.lowercased() == r.name.lowercased() }
        return clash ? .notAvailable("You already have a preset named \u{201C}\(r.name)\u{201D}.") : nil
    }

    /// Every stored record of every kind; empty when the file is missing or can't be read.
    private func current() -> [PresetRecord] {
        (try? store.read(Self.file, as: [PresetRecord].self).value) ?? []
    }
}
