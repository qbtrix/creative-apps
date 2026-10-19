// LibraryDevelop.swift: the Develop tab's state and edits (feature develop).
// DV-2 lands every signature with a body that changes nothing, so the panel
// (DV-8 to DV-10) builds over them; DV-3 fills the slider, curve and levels
// edits, the drag's end, the resets and the helps, and DV-4 copy, paste,
// sync and the histogram helpers. Every edit goes through `recordEdit`, the
// catalog's undo history. Linux-safe.

extension LibraryCatalog {
    /// The loupe photo in the loupe, else the selection.
    public var developTargets: Set<String> { [] }
    /// "Select a photo to develop it." with no targets, else nil.
    public var developHelp: String? { nil }

    /// Why `slider` can't change on these services: on the live services,
    /// `LiveDevelop.waiting[slider]`; nil on the fakes and once it renders.
    public func sliderHelp(_ slider: DevelopSlider) -> String? { nil }
    /// The targets' value, "Mixed" when they differ; nil with no targets.
    public func developValue(_ slider: DevelopSlider) -> MetadataValue<Double>? { nil }
    /// The targets' curve, mixed when they differ; nil with no targets.
    public var developCurve: MetadataValue<ToneCurve>? { nil }
    /// The targets' levels, mixed when they differ; nil with no targets.
    public var developLevels: MetadataValue<DevelopLevels>? { nil }

    /// Every target to `value` (clamped). Edits sharing an open `coalesceKey`
    /// (one drag, "develop-exposure") are one step named after the slider.
    public mutating func setDevelop(_ slider: DevelopSlider, to value: Double, coalesceKey: String?) {}
    /// Every target's curve to `points` as the step "Curve"; points that make no curve are ignored.
    public mutating func setCurve(_ points: [DevelopCurvePoint], coalesceKey: String?) {}
    /// Every target's levels `field` to `value` (clamped) as the step "Levels".
    public mutating func setLevels(_ field: DevelopLevels.Field, to value: Double, coalesceKey: String?) {}

    /// Ends the gesture: the next edit is a new step. Drops the held thumbnails
    /// of the photos the gesture changed and returns their ids.
    @discardableResult public mutating func endDevelopDrag() -> Set<String> { [] }

    /// nil: every adjustment ("Reset Develop"), never the crop; .tone or .color: "Reset Tone", "Reset Color".
    @discardableResult public mutating func resetDevelop(_ group: DevelopGroup?) -> Set<String> { [] }
    /// One slider back to 0: "Reset Exposure".
    @discardableResult public mutating func resetDevelop(_ slider: DevelopSlider) -> Set<String> { [] }
    /// The identity curve: "Reset Curve".
    @discardableResult public mutating func resetCurve() -> Set<String> { [] }
    /// Neutral levels: "Reset Levels".
    @discardableResult public mutating func resetLevels() -> Set<String> { [] }

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
