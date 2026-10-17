// FakeCreating.swift: the reference DocumentCreating (UC-3), pure. Each
// app's New tile with its presets; a missing app's tile is disabled with
// `appMissing`'s sentence, else with `unavailable` when set.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct FakeCreating: DocumentCreating {
    let unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    /// The live type's presets (each app's own preset list).
    public static let presets = SuiteCreating.presets

    public func tiles(missing: Set<SuiteApp>) -> [NewTile] {
        SuiteCreating().tiles(missing: missing).map { var t = $0; t.disabledReason = t.disabledReason ?? unavailable; return t }
    }

    public func handOff(for preset: NewDocumentPreset, id: String, at date: Date) -> HandOff {
        SuiteCreating().handOff(for: preset, id: id, at: date)
    }
}
