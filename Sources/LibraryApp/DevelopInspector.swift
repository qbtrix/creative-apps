// DevelopInspector.swift: the inspector's Develop tab (develop DV-9). While a
// crop draft is set it hosts CropInspector with the window's crop controls
// (`\.libraryCrop`, crop CR-6). With no photo to develop it is an
// EmptyStateView saying why (`developHelp`). Otherwise, top to bottom (the
// histogram sits above both tabs, in LibraryInspector): the render error
// (`library.develop.error`), LOOKS (SuiteUI's LookGrid, `suite.looks.*`,
// AJ-11), the TONE and COLOR
// sections with one bar row per slider ("Mixed" while the targets differ, a
// Reset context menu per row, its `photo.reset-<slider>` spec's MenuCommand
// (CS-6), the section reset while any row is off 0), BLACK & WHITE (a
// checkbox and six weights, `library.develop.bw.*`, via `\.libraryAdjust`),
// CURVE (SuiteUI's ToneCurveEditor over the targets' curve, its engine
// samples and the loupe histogram, `library.develop.curve`) and LEVELS
// (SuiteUI's LevelsHandles: Black Point, Midtones and White Point on the
// input ramp, Output Black and Output White under it, read 0...255 and
// Midtones to two places, `library.develop.levels.<field>`), each with its
// reset while off neutral (DV-10),
// Show Original (`\`), Sync from the first selected photo, and Paste
// Settings with the copied settings named under it. Each row and action
// carries its `library.develop.*` identifier and is off, saying why, while
// its LibraryMenu closure is nil. Values in, closures out; it never writes
// LibraryCatalog. It shows no scroller (wheel, trackpad and keys still scroll).
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
                    DevelopLooksSection(model: model)
                    ForEach(DevelopGroup.allCases, id: \.self) { group in
                        InspectorSection(group.rawValue, onReset: sectionReset(group)) {
                            ForEach(group.sliders, id: \.self) { row($0) }
                        }
                    }
                    DevelopBlackAndWhiteSection(model: model, endEdit: develop.endEdit)
                    InspectorSection("Curve", onReset: curveReset) { curve }
                    InspectorSection("Levels", onReset: levelsReset) { levels }
                    actions
                }
                .accessibilityElement(children: .contain)
            }
            // No scroller: a legacy scroller's page area is an unnamed button
            // with no identifier to the app audit, as in LayerTreeList.
            .scrollIndicators(.never)
        }
    }

    private var develop: LibraryMenu.Develop { menu.photo.develop }

    /// The section's reset while one of its rows is off 0 (or mixed) and resets can run.
    private func sectionReset(_ group: DevelopGroup) -> (@MainActor () -> Void)? {
        guard let reset = develop.reset, group.sliders.contains(where: { model.developValue($0) != .value(0) })
        else { return nil }
        return { reset(group) }
    }

    /// The row's Reset item's action (its `photo.reset-<slider>` spec's), nil while resets can't run.
    private func reset(_ slider: DevelopSlider) -> LibraryMenu.Action? {
        guard let resetSlider = develop.resetSlider else { return nil }
        return { resetSlider(slider) }
    }

    private func row(_ slider: DevelopSlider) -> some View {
        let value = model.developValue(slider)
        let enabled = develop.set != nil && model.sliderHelp(slider) == nil
        let help = model.sliderHelp(slider) ?? Self.unavailable
        let set = develop.set
        let endEdit = develop.endEdit
        return InspectorSliderRow(
            slider.title, value: value?.shared ?? 0, in: slider.range, step: slider.step,
            unit: slider == .exposure ? "EV" : "", decimals: slider == .exposure ? 2 : 0, mixed: value == .mixed,
            onChange: { set?(slider, $0) }, onEnd: { endEdit?() }
        )
        .disabled(!enabled)
        .help(enabled ? "" : help)
        .contextMenu {
            MenuCommand(LibraryCatalog.resetSliderID(slider), on: model, action: reset(slider), reason: help)
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

    /// LEVELS: SuiteUI's handles over the targets' levels (neutral while mixed), each listed in library.controls.
    private var levels: some View {
        let levels: MetadataValue<DevelopLevels>? = model.developLevels
        let shown = levels?.shared ?? .neutral
        let setLevels: (@MainActor (DevelopLevels.Field, Double) -> Void)? = develop.setLevels
        let endEdit: (@MainActor () -> Void)? = develop.endEdit
        let enabled = setLevels != nil
        let entries = DevelopLevels.Field.allCases.map {
            ControlEntry(id: Self.levelsID($0), enabled: enabled, reason: enabled ? nil : Self.unavailable)
        }
        return LevelsHandles(
            LevelsValues(inBlack: shown.inBlack, gamma: shown.gamma, inWhite: shown.inWhite,
                         outBlack: shown.outBlack, outWhite: shown.outWhite),
            gammaRange: DevelopLevels.gammaRange, mixed: levels == .mixed, enabled: enabled, reason: Self.unavailable,
            id: { Self.levelsID(Self.field($0)) },
            onChange: { setLevels?(Self.field($0), $1) }, onEnd: { endEdit?() })
            .transformPreference(LibraryControlsKey.self) { $0 += entries }
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
    /// The LEVELS field a handle edits.
    nonisolated static func field(_ handle: LevelsHandle) -> DevelopLevels.Field {
        switch handle {
        case .inBlack: .inBlack
        case .gamma: .gamma
        case .inWhite: .inWhite
        case .outBlack: .outBlack
        case .outWhite: .outWhite
        }
    }
    nonisolated static func unit(_ point: DevelopCurvePoint) -> CGPoint { CGPoint(x: point.x, y: point.y) }
    /// `library.develop.exposure`, … `library.develop.saturation`.
    nonisolated static func rowID(_ slider: DevelopSlider) -> String {
        "library.develop.\(slider.rawValue.lowercased())"
    }
}
