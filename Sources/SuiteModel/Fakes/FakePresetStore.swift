// FakePresetStore.swift: the in-memory PresetStoring (adjust-everywhere
// AJ-2). Saving an id already stored replaces it; a name another preset of
// the kind already has, ignoring case, is refused; deleting an id that isn't
// stored is refused. With `unavailable:` set, every throwing call throws
// `.notAvailable(that sentence)` and `list` is empty.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

public final class FakePresetStore: PresetStoring {
    private let stored: Mutex<[PresetRecord]>
    let unavailable: String?

    public init(_ records: [PresetRecord] = [], unavailable: String? = nil) {
        stored = Mutex(records)
        self.unavailable = unavailable
    }

    public func list(kind: String) -> [PresetRecord] {
        if unavailable != nil { return [] }
        return stored.withLock { $0.filter { $0.kind == kind } }
    }

    public func save(_ r: PresetRecord) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        let refusal: SuiteError? = stored.withLock { all in
            let taken = all.contains { $0.kind == r.kind && $0.id != r.id && $0.name.lowercased() == r.name.lowercased() }
            if taken { return .notAvailable("You already have a preset named \u{201C}\(r.name)\u{201D}.") }
            if let i = all.firstIndex(where: { $0.kind == r.kind && $0.id == r.id }) { all[i] = r } else { all.append(r) }
            return nil
        }
        if let refusal { throw refusal }
    }

    public func delete(id: String, kind: String) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        let removed = stored.withLock { all in
            let before = all.count
            all.removeAll { $0.kind == kind && $0.id == id }
            return all.count < before
        }
        if !removed { throw .notAvailable("This preset was removed.") }
    }
}
