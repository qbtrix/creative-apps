// HaloTextLayerSnapshots.swift: Halo's TEXT section (#430, TX-6) on `empty`
// with the fake services and a new text layer, "Hello" at 96. The viewer
// drawing it beside the TEXT section (the field, the "96 px" size bar, the
// color row) at the inspector's ideal width (halo-text-layer-*), and the
// same after a blank commit, with "Enter some text." under the field that
// still holds "Hello" (halo-text-refused-*), the words in a filled row like
// Color's rather than a bordered field, and the whole layer inspector
// then, with that one caption under the field and none under TRANSFORM
// (halo-text-refused-inspector-*). Light and Dark. Also: the section draws
// nothing for a solid layer. macOS only.
import AppKit
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloTextLayerSnapshots {
    @Test func textLayer() throws {
        let project = try hello()
        #expect(project.selectedText?.string == "Hello")
        #expect(project.selectedText?.sizeText == "96 px")
        #expect(project.refusal == nil)
        #expect(project.unavailableHelp(for: .setText("Hello")) == nil)
        try snapshots(project, name: "halo-text-layer")
    }

    @Test func refusedBlankText() throws {
        var project = try hello()
        project.setText("   ")
        #expect(project.refusal == HaloRefusal(control: HaloTextInspector.stringID, message: "Enter some text."))
        #expect(project.selectedText?.string == "Hello")
        try snapshots(project, name: "halo-text-refused")
    }

    /// The whole layer inspector after a blank commit: one caption, under
    /// the field, none under TRANSFORM (#2175, #2181).
    @Test func refusedInTheWholeInspector() throws {
        var project = try hello()
        project.setText("")
        let refusal = try #require(project.refusal)
        #expect(HaloTextInspector.owns(refusal))
        #expect(project.textRefusal(at: HaloTextInspector.stringID) == refusal)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloLayerInspector(model: project)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 1100, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "halo-text-refused-inspector-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// The words sit in a filled Studio row like Color's below them, not a
    /// bordered system field: down a column just inside the rows' leading
    /// edge, the first row (the field) has the Color row's fill and height.
    /// Before the fix it was a short white bordered box.
    @Test func fieldIsAStudioRow() throws {
        let model = try hello()
        for scheme in [ColorScheme.light, .dark] {
            let image = try #require(render(
                HaloTextInspector(model: model)
                    .padding(.vertical, SuiteSpacing.m)
                    .frame(width: SuiteSize.inspectorWidth.ideal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(SuiteColor.panel),
                scheme: scheme))
            let x = 16
            let background = image.colorAt(x: x, y: image.pixelsHigh - 1)
            var runs: [Range<Int>] = []
            var start: Int?
            for y in 0..<image.pixelsHigh {
                let filled = image.colorAt(x: x, y: y) != background
                if filled, start == nil { start = y }
                if !filled, let s = start { runs.append(s..<y); start = nil }
            }
            runs.removeAll { $0.count < 16 }  // the TEXT header's glyphs
            let field = try #require(runs.first, "no rows drawn (\(scheme.name))")
            let color = try #require(runs.last, "no rows drawn (\(scheme.name))")
            #expect(runs.count >= 3, "rows at \(runs) (\(scheme.name))")
            #expect(field.count == color.count, "field row \(field), color row \(color) (\(scheme.name))")
            #expect(
                image.colorAt(x: x, y: (field.lowerBound + field.upperBound) / 2)
                    == image.colorAt(x: x, y: (color.lowerBound + color.upperBound) / 2),
                "the field's fill differs from the Color row's (\(scheme.name))")
        }
    }

    @Test func noSectionForASolid() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
        project.newLayer(.solid)
        #expect(project.selectedText == nil)
        let solid = NSHostingView(rootView: HaloTextInspector(model: project).frame(width: SuiteSize.inspectorWidth.ideal))
        let text = NSHostingView(rootView: HaloTextInspector(model: try hello()).frame(width: SuiteSize.inspectorWidth.ideal))
        #expect(solid.fittingSize.height < 1)
        #expect(text.fittingSize.height > 0)
    }

    /// `empty` on `.fake` with a new text layer reading "Hello" at 96.
    private func hello() throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
        project.newLayer(.text)
        project.setText("Hello")
        project.setFontSize(96)
        project.endTextSizeScrub()
        return project
    }

    /// The viewer beside the TEXT section on the panel, as `<name>-light.png` and `<name>-dark.png`.
    private func snapshots(_ model: HaloProject, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HStack(spacing: 0) {
                    HaloViewer(model: model)
                    HaloTextInspector(model: model)
                        .padding(.vertical, SuiteSpacing.m)
                        .frame(width: SuiteSize.inspectorWidth.ideal)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(SuiteColor.panel)
                },
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
