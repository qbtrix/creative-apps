// LibraryTone+Kernel.swift (tone-controls LT-1 contract, LT-5 bodies): Library as a ToneTarget, so
// SuiteImaging's tone.* commands edit the develop targets' `DevelopSettings.tone`. LT-1 lands the
// adapter's shape: the settings and help read the catalog today; the edit and Auto throw `notBuilt`
// until LT-5 records them as develop steps and reads the loupe render's histogram. Linux-safe.
import CoreRaster
import SuiteImaging
import SuiteKernel

extension LibraryCatalog: ToneTarget {
    /// The first develop target's tone in `items` order; nil with no targets.
    public var toneSettings: ToneSettings? {
        let ids = developTargets
        return ids.isEmpty ? nil : items.first { ids.contains($0.id) }?.develop.tone
    }

    /// Develop's own reason first; then why the commands wait.
    public var toneHelp: String? { developHelp ?? "Tone commands wait on tone-controls LT-5." }

    /// Stub: LT-5 writes `s` to every develop target as one step named `name`.
    public mutating func setTone(_ s: ToneSettings, name: String, drag: String?) throws {
        throw CatalogError.notBuilt(id: "tone.set", feature: "tone-controls LT-5")
    }

    /// Stub: LT-5 reads Auto's suggestion from the loupe render's histogram.
    public func autoToneSuggestion() throws -> AutoTone {
        throw CatalogError.notBuilt(id: "tone.auto", feature: "tone-controls LT-5")
    }
}
