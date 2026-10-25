// PhotoTone+Kernel.swift (tone-controls PT-1 stubs, PT-4 bodies): the
// workspace as SuiteImaging's ToneTarget, so the suite's tone rows and the
// tone.* commands adjust Photo with no Photo tone type. The settings are the
// selected adjustment layer's `tone`, else the image's; nil with no image.
// Until PT-4 the rows and commands stay off with `toneHelp` saying so, and
// `setTone` and Auto throw notBuilt. Linux-safe.
import CoreRaster
import SuiteImaging
import SuiteKernel

extension PhotoWorkspace: ToneTarget {
    /// The task that fills `setTone` and Auto.
    static let toneNotBuilt = CatalogError.notBuilt(id: "tone", feature: "photo tone-controls PT-4")

    public var toneSettings: ToneSettings? {
        guard canvas != nil else { return nil }
        switch adjustTarget {
        case .image: return adjustments.tone
        case .layer(_, let settings): return settings.tone
        }
    }

    public var toneHelp: String? {
        canvas == nil ? "Open an image first." : "Not built yet (tone-controls PT-4)."
    }

    public mutating func setTone(_ s: ToneSettings, name: String, drag: String?) throws {
        throw Self.toneNotBuilt
    }

    public func autoToneSuggestion() throws -> AutoTone {
        throw Self.toneNotBuilt
    }
}
