// HaloEasingSnapshots.swift: Halo's EASING group (#428, EZ-6) on the `keyed`
// fixture. With Ball selected and Position X, frames 0–24 picked with Ease
// In and Out: the two rows (the picked one selected), the chips with Ease In
// and Out on, the curve and X1 Y1 X2 Y2 (halo-easing-*, and at the
// inspector's minimum width halo-easing-narrow-*). Ball with nothing picked:
// the rows and "Pick a key above." (halo-easing-unpicked-*). Floor, which
// has no property of two keys: collapsed (halo-easing-empty-collapsed-*) and
// opened, "Key a property to shape its easing." (halo-easing-empty-*). Light
// and Dark, at the inspector's ideal width. Geometry: every chip title and
// segment title fits on one line at the minimum width, the rows are filled,
// and the empty group adds no text height while collapsed (#1412, #1414,
// #1420, #1421). macOS only.
import AppKit
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloEasingSnapshots {
    /// x 0 picked with Ease In and Out: its row reads it, its chip is on.
    @Test func pickedSegment() throws {
        var project = try layer("Ball")
        let x0 = try #require(project.keySegments.first { $0.key.property == .x && $0.key.frame == 0 })
        project.selectKey(x0.key, extending: false)
        project.setEasing(.easeInOut)
        #expect(project.pickedSegment?.key == x0.key)
        #expect(project.pickedSegment?.easingTitle == "Ease In and Out")
        #expect(project.pickedPreset == .easeInOut)
        #expect(project.easingHandles != nil)
        #expect(project.easingCurve(count: 129).count == 129)
        #expect(project.refusal == nil)
        try snapshots(project, name: "halo-easing")
        try snapshots(project, name: "halo-easing-narrow", width: SuiteSize.inspectorWidth.min)
    }

    /// Ball's segments with none picked: the rows and "Pick a key above.".
    @Test func unpicked() throws {
        let project = try layer("Ball")
        #expect(project.keySegments.map(\.title) == ["Position X, frames 0–24", "Opacity, frames 0–12"])
        #expect(project.keySegments.map(\.easingTitle) == ["Linear", "Linear"])
        #expect(project.pickedSegment == nil)
        #expect(project.easingHandles == nil)
        try snapshots(project, name: "halo-easing-unpicked")
    }

    /// Floor has no property of two keys: collapsed, and opened "Key a property to shape its easing.".
    @Test func noSegments() throws {
        let project = try layer("Floor")
        #expect(project.keySegments.isEmpty)
        try snapshots(project, name: "halo-easing-empty", expandsWhenEmpty: true)
        try snapshots(project, name: "halo-easing-empty-collapsed")
    }

    /// #1412: with no segment the group opens collapsed, so its text adds no
    /// height under the inspector's fold.
    @Test func emptyGroupAddsNoTextHeight() throws {
        let project = try layer("Floor")
        let collapsed = height(HaloEasingInspector(model: project))
        let open = height(HaloEasingInspector(model: project, expandsWhenEmpty: true))
        let note = height(Text("Key a property to shape its easing.").font(SuiteFont.inspectorMeta))
        #expect(collapsed > 0)
        #expect(open - collapsed >= note - 0.5, "collapsed \(collapsed), open \(open), note \(note)")
    }

    /// #1414: each preset once, and every chip's title fits its cell at the
    /// inspector's minimum width (three a row cut "Ease In and Out").
    @Test func chipsFit() {
        let rows = HaloEasingInspector.chipRows
        #expect(
            rows.flatMap { $0 }.map(\.rawValue).sorted() == HaloEasingPreset.allCases.map(\.rawValue).sorted())
        let content = SuiteSize.inspectorWidth.min - 2 * SuiteSpacing.m
        for row in rows {
            let columns = CGFloat(row.count)
            let cell = (content - (columns - 1) * SuiteSpacing.xs) / columns
            for preset in row {
                let needs = width(preset.title, SuiteFont.caption.weight(.semibold)) + 2 * SuiteSpacing.s
                #expect(needs <= cell, "\(preset.title) needs \(needs) pt in a \(cell) pt chip")
            }
        }
    }

    /// #1420: a segment's title stays on one line beside its diamond at the
    /// inspector's minimum width (the value gives way first), and at the
    /// ideal width a short value fits beside it.
    @Test func segmentTitlesFitOneLine() throws {
        let project = try layer("Ball")
        let diamond = NSHostingView(
            rootView: Image(systemName: "diamond.fill").font(SuiteFont.rulerLabel).imageScale(.small)
        ).fittingSize.width
        // The section's inset and the row's padding, both sides; the two gaps.
        func room(_ inspector: CGFloat) -> CGFloat { inspector - 4 * SuiteSpacing.m - diamond - 2 * SuiteSpacing.s }
        let value = width("Linear", SuiteFont.inspectorValue)
        for segment in project.keySegments {
            let title = width(segment.title, SuiteFont.inspectorLabel)
            #expect(title <= room(SuiteSize.inspectorWidth.min), "\(segment.title) is \(title) pt at the minimum")
            #expect(title + value <= room(SuiteSize.inspectorWidth.ideal), "\(segment.title) and Linear at the ideal")
        }
    }

    /// #1421: rows sit on the Studio row's fill, the picked one on the
    /// selected well. #1415: X1 to Y2 explain themselves.
    @Test func rowsAreFilledAndHandlesExplained() {
        #expect(HaloEasingInspector.rowFill(picked: false, hovered: false) == SuiteColor.row)
        #expect(HaloEasingInspector.rowFill(picked: false, hovered: true) == SuiteColor.rowHover)
        #expect(HaloEasingInspector.rowFill(picked: true, hovered: true) == SuiteColor.selectedWell)
        for label in ["X1", "Y1", "X2", "Y2"] {
            let help = HaloEasingInspector.handleHelp(label)
            #expect(help != label)
            #expect(help.contains(label.hasSuffix("1") ? "first" : "second"))
            #expect(help.contains(label.hasPrefix("X") ? "Time" : "Progress"))
        }
    }

    /// `keyed` on `.fake` with the layer named `name` selected.
    private func layer(_ name: String) throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        let layer = try #require(project.selectedComposition?.layers.first { $0.name == name })
        project.selectLayer(layer.id)
        #expect(project.selectedLayer?.id == layer.id)
        return project
    }

    /// `text`'s one-line width in `font`.
    private func width(_ text: String, _ font: Font) -> CGFloat {
        NSHostingView(rootView: Text(text).font(font).lineLimit(1).fixedSize()).fittingSize.width
    }

    /// `view`'s height at the inspector's ideal width.
    private func height(_ view: some View) -> CGFloat {
        NSHostingView(rootView: view.frame(width: SuiteSize.inspectorWidth.ideal)).fittingSize.height
    }

    /// The EASING group in its column on the panel, as `<name>-light.png` and `<name>-dark.png`.
    private func snapshots(
        _ model: HaloProject, name: String, width: CGFloat = SuiteSize.inspectorWidth.ideal,
        expandsWhenEmpty: Bool = false
    ) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloEasingInspector(model: model, expandsWhenEmpty: expandsWhenEmpty)
                    .frame(width: width, height: 560, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "\(name)-\(scheme.name)", scheme: scheme)
        }
    }
}
