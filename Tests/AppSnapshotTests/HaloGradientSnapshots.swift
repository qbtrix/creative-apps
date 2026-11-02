// HaloGradientSnapshots.swift (gradient-fill HG-3): Halo's FILL section (HaloFillInspector) in its states. A radial
// fill shows SuiteUI's GradientEditor, its one Solid / Linear / Radial switch on Radial, with the fill's stops and no
// angle row (halo-fill-radial); a linear fill adds the angle (halo-fill-linear); both from values, white to black.
// A text layer shows no FILL in the whole layer inspector: text keeps its colour row in TEXT
// (halo-fill-text-layer). Also: on a new solid the section reads the project's solid fill in its layer's colour,
// the switch live on Solid over the layer's colour row. Light and Dark. macOS only.
import AppKit
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloGradientSnapshots {
    @Test func radialSolid() throws {
        let section = Self.section(Self.radial)
        #expect(section.type == .radial, "the switch reads Radial")
        #expect(GradientRules.angle(of: Self.radial.fill) == nil, "a radial fill has no angle row")
        try Self.both(Self.panel(section), name: "halo-fill-radial")
    }

    @Test func linear() throws {
        let section = Self.section(Self.linear)
        #expect(section.type == .linear, "the switch reads Linear")
        #expect(Self.typeSwitches(section) == [FillType.allCases.count], "FILL holds one Solid / Linear / Radial switch")
        try Self.both(Self.panel(section), name: "halo-fill-linear")
    }

    @Test func textLayer() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
        project.newLayer(.text)
        #expect(!HaloFillInspector.shows(project.selectedLayer?.kind), "a text layer shows no FILL")
        #expect(project.fillSelection == nil, "a text layer has no fill selection")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloLayerInspector(model: project)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 1100, alignment: .topLeading)
                    .background(SuiteColor.panel),
                name: "halo-fill-text-layer-\(scheme.name)", scheme: scheme)
        }
    }

    /// A new solid reads the project: a live switch on Solid, its fill the layer's colour, and its colour row.
    @Test func solidReadsItsFill() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
        project.newLayer(.solid)
        #expect(HaloFillInspector.shows(project.selectedLayer?.kind), "a solid shows FILL")
        let section = HaloFillInspector(model: project, perform: { _ in }, runFill: { _ in })
        #expect(section.help == nil, "a solid's switch is live, with no reason note")
        let color = try #require(project.selectedLayerColor, "a solid has a colour")
        #expect(
            section.selection?.fill == .solid(FillColor(r: color.red, g: color.green, b: color.blue, a: 1)),
            "the fill is the layer's colour")
        #expect(section.type == .solid, "no gradient reads Solid")
        #expect(section.color == color, "Solid shows the layer's colour row")
    }

    /// The editor's gestures and the switch's picks go out as GradientIntents to `runFill`.
    @Test func intentsGoToRunFill() {
        var sent: [GradientIntent] = []
        let section = HaloFillInspector(
            selection: Self.radial, help: nil, color: nil, colorHelp: nil, runFill: { sent.append($0) })
        section.runFill(.type(.linear))
        #expect(sent == [.type(.linear)], "a switch pick goes out as one fill command")
    }

    /// White at 0, black at 100%.
    private static let stops = [
        GradientStop(offset: 0, color: FillColor(r: 1, g: 1, b: 1)), GradientStop(offset: 1, color: FillColor(r: 0, g: 0, b: 0)),
    ]
    private static let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
    private static let radial = FillSelection(fill: .radial(stops: stops, center: Point(x: 50, y: 50), radius: 50), box: box)
    private static let linear = FillSelection(
        fill: .linear(stops: stops, start: Point(x: 0, y: 50), end: Point(x: 100, y: 50)), box: box)

    private static func section(_ selection: FillSelection) -> HaloFillInspector {
        HaloFillInspector(selection: selection, help: nil, color: nil, colorHelp: nil)
    }

    private static func panel(_ section: HaloFillInspector) -> some View {
        section
            .padding(.vertical, SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .top)
            .background(SuiteColor.panel)
    }

    /// The segment counts of the system segmented controls FILL hosts: one switch, SuiteUI's, never an app-local copy.
    private static func typeSwitches(_ section: HaloFillInspector) -> [Int] {
        let host = NSHostingView(rootView: panel(section))
        host.frame = CGRect(x: 0, y: 0, width: SuiteSize.inspectorWidth.ideal, height: 400)
        host.layoutSubtreeIfNeeded()
        func segmented(in view: NSView) -> [NSSegmentedControl] {
            (view as? NSSegmentedControl).map { [$0] } ?? view.subviews.flatMap(segmented)
        }
        return segmented(in: host).map(\.segmentCount)
    }

    /// Writes `<name>-light` and `<name>-dark`.
    private static func both(_ view: some View, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(view, name: "\(name)-\(scheme.name)", scheme: scheme)
        }
    }
}
