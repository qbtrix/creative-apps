// PhotoTone+Kernel.swift (tone-controls PT-1 stubs, PT-4 bodies): the
// workspace as SuiteImaging's ToneTarget, so the suite's tone rows and the
// tone.* commands adjust Photo with no Photo tone type. The settings are the
// selected adjustment layer's `tone`, else the image's; nil with no image.
// `setTone` writes that same target as one named step through the workspace's
// History (steps under one drag token fold); an adjustment layer takes no
// Sharpen (it reads neighbours), so its Sharpen rows say why and `setTone`
// refuses a Sharpen change there. Photo has its own Exposure, so the kernel's
// exposure (Auto's) folds into those stops and the tone keeps it at 0;
// `tone.set exposure` is refused. Auto reads CoreRaster's AutoTone from the
// composite the canvas shows. Linux-safe.
import CoreRaster
import SuiteImaging
import SuiteKernel

extension PhotoWorkspace: ToneTarget {
    /// Why an adjustment layer's Sharpen rows are off.
    static let sharpenOnLayer = "Sharpen is for the image."
    /// Why the kernel's Exposure slider is off: Photo's Exposure section is the one exposure.
    static let ownExposure = "Use Photo's Exposure."

    public var toneSettings: ToneSettings? {
        guard canvas != nil else { return nil }
        switch adjustTarget {
        case .image: return adjustments.tone
        case .layer(_, let settings): return settings.tone
        }
    }

    public var toneHelp: String? { canvas == nil ? Self.noImage : nil }

    /// Why slider `s` is off now: `toneHelp`, Sharpen on an adjustment layer, or a slider the suite has waiting.
    public func toneSliderHelp(_ s: ToneSlider) -> String? {
        if let help = toneHelp { return help }
        if s == .exposure { return Self.ownExposure }
        if s.group == .sharpen, case .layer = adjustTarget { return Self.sharpenOnLayer }
        return ToneRules.waiting[s]
    }

    public mutating func setTone(_ s: ToneSettings, name: String, drag: String?) throws {
        if let help = toneHelp { throw CatalogError.unavailable(id: "tone", why: help) }
        if name == ToneSlider.exposure.title, s.value(.exposure) != 0 {
            throw CatalogError.unavailable(id: "tone.set", why: Self.ownExposure)
        }
        if case .layer(let id, let settings) = adjustTarget {
            return try setLayerTone(s, of: id, settings, name: name, drag: drag)
        }
        let next = Self.folding(s, into: adjustments)
        guard next != adjustments else { return }
        record(.adjustments(adjustments), named: name, coalescing: drag.map { "tone-image-\($0)" })
        adjustments = next
        touch(.all, adjustmentsOnly: true)
    }

    /// Adjustment layer `id`'s tone becomes `s`, Sharpen left as it is, in one step.
    private mutating func setLayerTone(
        _ s: ToneSettings, of id: PhotoLayer.ID, _ settings: AdjustmentSettings, name: String, drag: String?
    ) throws {
        guard ToneGroup.sharpen.sliders.allSatisfy({ s.value($0) == settings.tone.value($0) }) else {
            throw CatalogError.unavailable(id: "tone", why: Self.sharpenOnLayer)
        }
        let next = Self.folding(s, into: settings)
        guard next != settings, let at = index(of: id) else { return }
        recordLayers(named: name, coalescing: drag.map { "tone-layer-\(id)-\($0)" })
        layers[at].kind = .adjustment(next)
        touch(.all)
    }

    /// `settings` with tone `s`: its exposure added to Exposure's stops (turned on), the tone kept at exposure 0.
    static func folding(_ s: ToneSettings, into settings: AdjustmentSettings) -> AdjustmentSettings {
        var next = settings
        let stops = s.value(.exposure)
        if stops != 0 {
            next.apply(.exposure(settings.exposure + Float(stops)))
            next.apply(.setEnabled(.exposure, true))
        }
        next.apply(.tone(s.setting(.exposure, to: 0)))
        return next
    }

    /// One CPU read of the whole composite per click, never per slider step.
    public func autoToneSuggestion() throws -> AutoTone {
        if let help = toneHelp { throw CatalogError.unavailable(id: "tone.auto", why: help) }
        return try AutoTone.suggest(for: composite())
    }
}
