// LibraryLooks+Kernel.swift (adjust-everywhere AJ-10): the catalog as an
// AdjustTarget, so `AdjustCommands.specs` gives Library Black & White, Invert
// and the looks. Kinds and looks act on the develop targets (the loupe photo,
// else the selection) as one undo step through `developStep`, which also drops
// the changed thumbnails. Filters stay in Photo: every filter command is off
// with `filtersInPhoto`. A look replaces the targets' sliders, curve, levels
// and kinds and keeps each crop; a slider the live renderer can't draw yet
// (`sliderHelp`) stays at 0. Linux-safe.
import SuiteImaging
import SuiteKernel
import SuiteModel

extension LibraryCatalog: AdjustTarget {
    /// Why Library runs no filter.
    public static let filtersInPhoto = "Filters are in Photo."

    public var adjustHelp: String? { services.unavailable["develop"] ?? developHelp }
    public var filterHelp: String? { Self.filtersInPhoto }

    /// The first develop target's kinds, in `items` order; none with no targets.
    public var kinds: [ImagingKind] { firstDevelopTarget?.kinds ?? [] }

    public mutating func setKinds(_ k: [ImagingKind], name: String) {
        _ = developStep(name) { $0.setting(kinds: k) }
    }

    public mutating func applyFilter(_ f: ImagingFilter, name: String) throws {
        throw CatalogError.unavailable(id: "filter.\(f.id)", why: Self.filtersInPhoto)
    }

    public mutating func applyLook(_ l: LookPreset, name: String) {
        let ids = developTargets
        let live = ToneSlider.develop.filter { sliderHelp($0) == nil }
        _ = developStep(name, ids: ids) { Self.developing(l, keeping: $0, sliders: live) }
    }

    /// The first develop target's settings as an unsaved look.
    public var currentLook: LookPreset {
        let s = firstDevelopTarget ?? .neutral
        let l = s.levels
        let adjust = AdjustSettings(
            levels: AdjustLevels(inputBlack: l.inBlack, inputWhite: l.inWhite, gamma: l.gamma, outputBlack: l.outBlack, outputWhite: l.outWhite),
            curve: AdjustCurve(points: s.curve.points.map { AdjustCurvePoint(x: $0.x, y: $0.y) }))
        return LookPreset(id: "current", name: "Current", tone: s.tone, adjust: adjust, kinds: s.kinds)
    }

    public var looks: any PresetStoring { services.looks }

    /// `look` over neutral settings with `old`'s crop: the `sliders` it carries (exposure adds the
    /// adjust exposure), its levels and curve, and its kinds.
    static func developing(_ look: LookPreset, keeping old: DevelopSettings, sliders: [ToneSlider]) -> DevelopSettings {
        var s = DevelopSettings.neutral.setting(crop: old.crop)
        for slider in sliders {
            s = s.setting(slider, to: look.tone.value(slider) + (slider == .exposure ? look.adjust.exposure : 0))
        }
        let a = look.adjust.levels
        let fields: [(DevelopLevels.Field, Double)] = [
            (.outBlack, a.outputBlack), (.outWhite, a.outputWhite), (.gamma, a.gamma), (.inWhite, a.inputWhite), (.inBlack, a.inputBlack),
        ]
        s = s.setting(levels: fields.reduce(DevelopLevels.neutral) { $0.setting($1.0, to: $1.1) })
        s = s.setting(curve: ToneCurve(points: look.adjust.curve.points.map { DevelopCurvePoint(x: $0.x, y: $0.y) }) ?? .identity)
        return s.setting(kinds: look.kinds)
    }

    /// The first develop target's settings, in `items` order.
    private var firstDevelopTarget: DevelopSettings? {
        let ids = developTargets
        return items.first { ids.contains($0.id) }?.develop
    }
}
