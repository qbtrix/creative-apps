// DocumentCreating.swift: UC-3, new document by type (tier 1). Foundation
// only for `Date`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-3 New document by type (tier 1). Pure: presets come from each app's
/// own preset list (mirrored here), creating one makes the hand-off to send.
public protocol DocumentCreating: Sendable {
    func tiles(missing: Set<SuiteApp>) -> [NewTile]
    func handOff(for preset: NewDocumentPreset, id: String, at date: Date) -> HandOff
}
