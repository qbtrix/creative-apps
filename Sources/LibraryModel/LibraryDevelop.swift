// LibraryDevelop.swift: the Develop tab's state and edits (feature develop).
// DV-2 landed every signature with a body that changes nothing, so the panel
// (DV-8 to DV-10) builds over them; DV-3 fills the slider, curve and levels
// edits, the drag's end, the resets and the helps, and DV-4 copy, paste,
// sync and the histogram helpers. Every edit goes through `recordEdit`, the
// catalog's undo history; a drag's samples share one coalesce key, and the
// grid's thumbnails of the changed photos drop once, when the drag ends.
// Linux-safe.

extension LibraryCatalog {
    /// The loupe photo in the loupe, else the selection.
    public var developTargets: Set<String> {
        if mode == .loupe { return loupeItem.map { [$0.id] } ?? [] }
        return selection
    }
    /// "Select a photo to develop it." with no targets, else nil.
    public var developHelp: String? { developTargets.isEmpty ? "Select a photo to develop it." : nil }

    /// Why `slider` can't change on these services: on the live services,
    /// `LiveDevelop.waiting[slider]`; nil on the fakes and once it renders.
    public func sliderHelp(_ slider: DevelopSlider) -> String? {
        services.develop is LiveDevelop ? LiveDevelop.waiting[slider] : nil
    }
    /// The targets' value, "Mixed" when they differ; nil with no targets.
    public func developValue(_ slider: DevelopSlider) -> MetadataValue<Double>? {
        MetadataValue.of(developTargetSettings.map { $0.value(slider) })
    }
    /// The targets' curve, mixed when they differ; nil with no targets.
    public var developCurve: MetadataValue<ToneCurve>? { MetadataValue.of(developTargetSettings.map(\.curve)) }
    /// The targets' levels, mixed when they differ; nil with no targets.
    public var developLevels: MetadataValue<DevelopLevels>? { MetadataValue.of(developTargetSettings.map(\.levels)) }

    /// Every target to `value` (clamped). Edits sharing an open `coalesceKey`
    /// (one drag, "develop-exposure") are one step named after the slider.
    /// No thumbnail work per sample: the grid keeps its picture until release.
    public mutating func setDevelop(_ slider: DevelopSlider, to value: Double, coalesceKey: String?) {
        let ids = developTargets
        guard !ids.isEmpty, sliderHelp(slider) == nil else { return }
        recordEdit(slider.rawValue, coalesceKey: coalesceKey, ids: ids) { $0.develop = $0.develop.setting(slider, to: value) }
    }
    /// Every target's curve to `points` as the step "Curve"; points that make no curve are ignored.
    public mutating func setCurve(_ points: [DevelopCurvePoint], coalesceKey: String?) {
        guard let curve = ToneCurve(points: points) else { return }
        recordEdit("Curve", coalesceKey: coalesceKey, ids: developTargets) { $0.develop = $0.develop.setting(curve: curve) }
    }
    /// Every target's levels `field` to `value` (clamped) as the step "Levels".
    public mutating func setLevels(_ field: DevelopLevels.Field, to value: Double, coalesceKey: String?) {
        recordEdit("Levels", coalesceKey: coalesceKey, ids: developTargets) {
            $0.develop = $0.develop.setting(levels: $0.develop.levels.setting(field, to: value))
        }
    }

    /// Ends the gesture: the next edit is a new step. Drops the held thumbnails
    /// of the photos the gesture changed and returns their ids.
    @discardableResult public mutating func endDevelopDrag() -> Set<String> {
        let ids = history.open ? history.top.map(Self.developChanged) ?? [] : []
        endCoalescing()
        for id in ids { invalidateThumbnail(id) }
        return ids
    }

    /// nil: every adjustment ("Reset Develop"), never the crop; .tone or .color: "Reset Tone", "Reset Color".
    @discardableResult public mutating func resetDevelop(_ group: DevelopGroup?) -> Set<String> {
        let sliders = group?.sliders ?? DevelopSlider.allCases
        return developStep(group.map { "Reset " + $0.rawValue } ?? "Reset Develop") { settings in
            let reset = sliders.reduce(settings) { $0.setting($1, to: 0) }
            return group == nil ? reset.setting(curve: .identity).setting(levels: .neutral) : reset
        }
    }
    /// One slider back to 0: "Reset Exposure".
    @discardableResult public mutating func resetDevelop(_ slider: DevelopSlider) -> Set<String> {
        developStep("Reset " + slider.rawValue) { $0.setting(slider, to: 0) }
    }
    /// The identity curve: "Reset Curve".
    @discardableResult public mutating func resetCurve() -> Set<String> {
        developStep("Reset Curve") { $0.setting(curve: .identity) }
    }
    /// Neutral levels: "Reset Levels".
    @discardableResult public mutating func resetLevels() -> Set<String> {
        developStep("Reset Levels") { $0.setting(levels: .neutral) }
    }

    /// The targets' settings, in `items` order; empty with no targets.
    private var developTargetSettings: [DevelopSettings] {
        let ids = developTargets
        return ids.isEmpty ? [] : items.filter { ids.contains($0.id) }.map(\.develop)
    }

    /// The ids of the photos whose develop settings `step` changed.
    private static func developChanged(_ step: CatalogHistory.Step) -> Set<String> {
        Set(zip(step.before, step.after).filter { $0.develop != $1.develop }.map(\.1.id))
    }

    /// `change` on every target as a step `name` of its own, closed at once
    /// (an open drag ends first); drops the changed photos' thumbnails and
    /// returns their ids, none when nothing changed.
    private mutating func developStep(_ name: String, _ change: (DevelopSettings) -> DevelopSettings) -> Set<String> {
        endDevelopDrag()
        let steps = history.undo.count
        recordEdit(name, ids: developTargets) { $0.develop = change($0.develop) }
        return history.undo.count > steps ? endDevelopDrag() : []
    }

    /// The loupe photo's settings, else the single selected photo's; nothing with 0 or several.
    public mutating func copySettings() {}
    /// Copied settings and at least one target.
    public var canPasteSettings: Bool { false }
    /// "Exposure +1.00, Contrast 13, Curve": the copied settings off neutral, in panel order.
    public var copiedSummary: String? { nil }

    /// The copied adjustments onto every target, keeping each one's crop: one step "Paste Settings".
    @discardableResult public mutating func pasteSettings() -> Set<String> { [] }

    /// In the grid with 2 or more selected: the first selected photo in the shown order.
    public var syncSource: PhotoItem? { nil }
    /// "Sync from IMG_0001".
    public var syncTitle: String? { nil }

    /// The source's adjustments onto the rest of the selection, crops kept: one step "Sync Settings".
    @discardableResult public mutating func syncSettings() -> Set<String> { [] }

    /// The loupe's render error, shown in the panel.
    public var developError: String? { nil }
    /// "Shadows clipped", "Highlights clipped" while any pixel clips.
    public var histogramClips: [String] { [] }
    /// The loupe histogram's three channels summed per bin, scaled 0...1, for the curve's backdrop.
    public var curveHistogram: [Double] { [] }
}
