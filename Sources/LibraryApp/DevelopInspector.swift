// DevelopInspector.swift: the inspector's Develop tab (develop DV-9). While a
// crop draft is set it hosts CropInspector with the window's crop controls
// (`\.libraryCrop`, crop CR-6). With no photo to develop it is an
// EmptyStateView saying why (`developHelp`). Otherwise, top to bottom (the
// histogram sits above both tabs, in LibraryInspector): the render error
// (`library.develop.error`), the TONE and COLOR
// sections with one bar row per slider ("Mixed" while the targets differ, a
// Reset context menu per row, the section reset while any row is off 0),
// CURVE (SuiteUI's ToneCurveEditor over the targets' curve, its engine
// samples and the loupe histogram, `library.develop.curve`) and LEVELS (a
// row per field, 0...255 whole numbers, Midtones 0.10...9.99 with two places,
// `library.develop.levels.<field>`), each with its reset while off neutral (DV-10),
// Show Original (`\`), Sync from the first selected photo, and Paste
// Settings with the copied settings named under it. Each row and action
// carries its `library.develop.*` identifier and is off, saying why, while
// its LibraryMenu closure is nil. Values in, closures out; it never writes
// LibraryCatalog.
import LibraryModel
import SuiteUI
import SwiftUI

struct DevelopInspector: View {
    let model: LibraryCatalog
    /// The window's menu, whose actions the Develop tab calls.
    let menu: LibraryMenu
    let cropDraft: CropSettings?
    @Environment(\.libraryCrop) private var crop

    var body: some View {
        if cropDraft != nil {
            CropInspector(crop: crop)
        } else if let help = model.developHelp {
            EmptyStateView("Develop", systemImage: "slider.horizontal.3", message: help)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    if let error = model.developError {
                        InspectorNote(error, kind: .error, identifier: Self.errorID)
                    }
                    ForEach(DevelopGroup.allCases, id: \.self) { group in
                        InspectorSection(group.rawValue, onReset: sectionReset(group)) {
                            ForEach(group.sliders, id: \.self) { row($0) }
                        }
                    }
                    InspectorSection("Curve", onReset: curveReset) { curve }
                    InspectorSection("Levels", onReset: levelsReset) {
                        ForEach(DevelopLevels.Field.allCases, id: \.self) { levelsRow($0) }
                    }
                    actions
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private var develop: LibraryMenu.Develop { menu.photo.develop }

    /// The section's reset while one of its rows is off 0 (or mixed) and resets can run.
    private func sectionReset(_ group: DevelopGroup) -> (@MainActor () -> Void)? {
        guard let reset = develop.reset, group.sliders.contains(where: { model.developValue($0) != .value(0) })
        else { return nil }
        return { reset(group) }
    }

    private func row(_ slider: DevelopSlider) -> some View {
        let value = model.developValue(slider)
        let enabled = develop.set != nil && model.sliderHelp(slider) == nil
        let help = model.sliderHelp(slider) ?? Self.unavailable
        let set = develop.set
        let endEdit = develop.endEdit
        let resetSlider = develop.resetSlider
        return InspectorSliderRow(
            slider.rawValue, value: value?.shared ?? 0, in: slider.range, step: slider.step,
            unit: slider == .exposure ? "EV" : "", decimals: slider == .exposure ? 2 : 0, mixed: value == .mixed,
            onChange: { set?(slider, $0) }, onEnd: { endEdit?() }
        )
        .disabled(!enabled)
        .help(enabled ? "" : help)
        .contextMenu {
            Button("Reset \(slider.rawValue)") { resetSlider?(slider) }
                .disabled(resetSlider == nil)
        }
        .libraryControl(id: Self.rowID(slider), enabled: enabled, help: help)
    }

    /// The curve's reset while the targets' curve is off the identity (or mixed) and resets can run.
    private var curveReset: (@MainActor () -> Void)? {
        guard let reset = develop.resetCurve, model.developCurve != .value(.identity) else { return nil }
        return reset
    }

    /// The levels' reset while the targets' levels are off neutral (or mixed) and resets can run.
    private var levelsReset: (@MainActor () -> Void)? {
        guard let reset = develop.resetLevels, model.developLevels != .value(.neutral) else { return nil }
        return reset
    }

    /// The tone curve over the targets' curve (the identity while mixed), its engine samples and the loupe histogram.
    private var curve: some View {
        let shown: ToneCurve = model.developCurve?.shared ?? .identity
        let points: [CGPoint] = shown.points.map(Self.unit)
        let samples: [CGPoint] = shown.samples().map(Self.unit)
        let setCurve: (@MainActor ([DevelopCurvePoint]) -> Void)? = develop.setCurve
        let endEdit: (@MainActor () -> Void)? = develop.endEdit
        let onChange: @MainActor ([CGPoint]) -> Void = { (moved: [CGPoint]) -> Void in
            setCurve?(moved.map { DevelopCurvePoint(x: Double($0.x), y: Double($0.y)) })
        }
        let onEnd: @MainActor () -> Void = { () -> Void in endEdit?() }
        let enabled = setCurve != nil
        let entry = ControlEntry(id: Self.curveID, enabled: enabled, reason: enabled ? nil : Self.unavailable)
        return ToneCurveEditor(
            points: points, samples: samples, histogram: model.toneHistogram.heights, id: Self.curveID,
            onChange: onChange, onEnd: onEnd)
            .disabled(!enabled)
            .help(enabled ? "" : Self.unavailable)
            .transformPreference(LibraryControlsKey.self) { $0.append(entry) }
    }

    /// One LEVELS row: the field as 0...255 whole numbers, Midtones as 0.10...9.99 with two places.
    private func levelsRow(_ field: DevelopLevels.Field) -> some View {
        let levels: MetadataValue<DevelopLevels>? = model.developLevels
        let scale: Double = Self.levelsScale(field)
        let value: Double = (levels?.shared ?? .neutral).value(field) * scale
        let setLevels: (@MainActor (DevelopLevels.Field, Double) -> Void)? = develop.setLevels
        let endEdit: (@MainActor () -> Void)? = develop.endEdit
        let onChange: @MainActor (Double) -> Void = { (shown: Double) -> Void in setLevels?(field, shown / scale) }
        let onEnd: @MainActor () -> Void = { () -> Void in endEdit?() }
        let enabled = setLevels != nil
        let isGamma = field == .gamma
        return InspectorSliderRow(
            field.rawValue, value: value, in: Self.levelsRange(field), step: isGamma ? 0.01 : 1,
            decimals: isGamma ? 2 : 0, mixed: levels == .mixed, onChange: onChange, onEnd: onEnd)
            .disabled(!enabled)
            .help(enabled ? "" : Self.unavailable)
            .libraryControl(id: Self.levelsID(field), enabled: enabled, help: Self.unavailable)
    }

    /// Show Original, Sync and Paste Settings, with the copied settings named under Paste.
    @ViewBuilder private var actions: some View {
        let original = ToolbarAction(
            "Show Original", systemImage: "eye", isSelected: develop.showsOriginal,
            unavailableHelp: develop.toggleOriginal == nil ? "Open a photo in the loupe to compare it with its original." : nil,
            shortcut: "\\", identifier: "library.develop.original", perform: { develop.toggleOriginal?() })
        InspectorAction(original)
            .keyboardShortcut("\\", modifiers: [])
            .libraryControl(original)
        let sync = ToolbarAction(
            develop.syncTitle ?? "Sync Settings", systemImage: "arrow.triangle.2.circlepath",
            unavailableHelp: develop.sync == nil ? "Select two or more photos in the grid to sync them." : nil,
            identifier: "library.develop.sync", perform: { develop.sync?() })
        InspectorAction(sync).libraryControl(sync)
        let paste = ToolbarAction(
            "Paste Settings", systemImage: "doc.on.clipboard",
            unavailableHelp: menu.photo.pasteSettings == nil ? "Copy a photo's settings first (Photo > Copy Settings)." : nil,
            identifier: "library.develop.paste", perform: { menu.photo.pasteSettings?() })
        InspectorAction(paste).libraryControl(paste)
        if let copied = model.copiedSummary {
            // A plain line until InspectorAction takes help while enabled (needs-ui).
            InspectorNote("Copied: \(copied)", identifier: "library.develop.copied")
        }
    }

    /// Why a row is off when its closure is nil (outside a window).
    nonisolated static let unavailable = "Open a photo or select photos in the grid to develop them."
    /// The histogram above the tabs (LibraryInspector) keeps the develop panel's id.
    nonisolated static let histogramID = "library.develop.histogram"
    nonisolated static let errorID = "library.develop.error"
    nonisolated static let curveID = "library.develop.curve"
    /// `library.develop.levels.blackpoint`, `….midtones`, … `….outputwhite`.
    nonisolated static func levelsID(_ field: DevelopLevels.Field) -> String {
        "library.develop.levels." + String(field.rawValue.lowercased().filter { $0 != " " })
    }
    /// What a LEVELS row shows per stored unit: 255 for the points (sRGB 0...1 as 0...255), 1 for Midtones.
    nonisolated static func levelsScale(_ field: DevelopLevels.Field) -> Double { field == .gamma ? 1 : 255 }
    /// The row's range in shown units.
    nonisolated static func levelsRange(_ field: DevelopLevels.Field) -> ClosedRange<Double> {
        field == .gamma ? DevelopLevels.gammaRange : 0...255
    }
    nonisolated static func unit(_ point: DevelopCurvePoint) -> CGPoint { CGPoint(x: point.x, y: point.y) }
    /// `library.develop.exposure`, … `library.develop.saturation`.
    nonisolated static func rowID(_ slider: DevelopSlider) -> String {
        "library.develop.\(slider.rawValue.lowercased())"
    }
}
