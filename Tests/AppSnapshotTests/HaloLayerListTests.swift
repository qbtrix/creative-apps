// HaloLayerListTests.swift: pixel checks on the inspector's LAYERS rows
// (HaloLayerList) drawn alone in a 240 pt column on the panel, Light and
// Dark. The selected row spans the column edge to edge (no List inset), in
// the stateSelected tint with an accent outline, not the system's grey; the
// icons start SuiteSpacing.m in; layer names clear 4.5:1 on the panel; and a
// composition with no layers draws its hint. macOS only.
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloLayerListTests {
    private static let width = 240

    /// The list at the top left of a panel-filled image.
    private func image(_ project: HaloProject, _ scheme: ColorScheme) throws -> NSBitmapImageRep {
        let list = HaloLayerList(model: project)
            .frame(width: CGFloat(Self.width))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SuiteColor.panel)
        return try #require(render(list, scheme: scheme))
    }

    /// Three layers with Title, the top row, selected.
    private func threeLayers() throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
        project.selectLayer("comp-1-layer-4")
        return project
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func selectedRowSpansTheColumnInTheSelectedTint(scheme: ColorScheme) throws {
        let image = try image(try threeLayers(), scheme)
        let panel = try #require(rgb(image, 700, 450))
        let edge = Int(SuiteSize.studioRow / 2)
        // Both outline edges sit on the column's edges, so no List inset.
        for x in [0, Self.width - 1] {
            let px = try #require(rgb(image, x, edge))
            #expect(distance(px, panel) > 0.05, "nothing drawn at x \(x) of the selected row (\(scheme))")
        }
        let outside = try #require(rgb(image, Self.width + 1, edge))
        #expect(distance(outside, panel) < 0.02, "the selected row runs past the column (\(scheme))")
        // Its fill is the blue stateSelected tint, not the grey system highlight.
        let fill = try #require(rgb(image, Self.width - 20, edge))
        #expect(fill.b - fill.r > 0.03, "the selected row's fill isn't the selected tint: \(fill) (\(scheme))")
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func rowsStartOnTheInsetAndNamesUsePrimaryInk(scheme: ColorScheme) throws {
        let image = try image(try threeLayers(), scheme)
        let panel = try #require(rgb(image, 700, 450))
        // The second row (Badge), below the selected one.
        let top = Int(SuiteSize.studioRow + SuiteSpacing.xs)
        let band = top..<(top + Int(SuiteSize.studioRow))
        let inked = (0..<Self.width).first { x in
            band.contains { y in rgb(image, x, y).map { distance($0, panel) > 0.2 } ?? false }
        }
        let first = try #require(inked, "the second row drew nothing (\(scheme))")
        #expect((Int(SuiteSpacing.m)...Int(SuiteSpacing.m) + 6).contains(first),
                "the row's icon starts \(first) pt in, not on the SuiteSpacing.m inset (\(scheme))")
        // The name, right of the icon: its darkest (or brightest) ink against the panel.
        var best = 1.0
        for y in band {
            for x in 44..<200 {
                if let px = rgb(image, x, y) { best = max(best, contrast(px, panel)) }
            }
        }
        #expect(best >= 4.5, "the layer name reads \(best):1 on the panel (\(scheme))")
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func emptyCompositionShowsTheHint(scheme: ColorScheme) throws {
        var project = HaloProject()
        project.newComposition()
        #expect(project.selectedComposition?.layers.isEmpty == true)
        let image = try image(project, scheme)
        let panel = try #require(rgb(image, 700, 450))
        var inked = 0
        for y in stride(from: 0, to: 40, by: 1) {
            for x in stride(from: 0, to: Self.width, by: 2) {
                if let px = rgb(image, x, y), distance(px, panel) > 0.2 { inked += 1 }
            }
        }
        #expect(inked > 20, "no empty-layers hint under LAYERS (\(inked) inked samples, \(scheme))")
    }
}

private struct RGB { var r: Double, g: Double, b: Double }

@MainActor
private func rgb(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) -> RGB? {
    guard let c = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return nil }
    return RGB(r: c.redComponent, g: c.greenComponent, b: c.blueComponent)
}

private func distance(_ a: RGB, _ b: RGB) -> Double {
    max(abs(a.r - b.r), abs(a.g - b.g), abs(a.b - b.b))
}

/// The WCAG contrast ratio of two sRGB colors.
private func contrast(_ a: RGB, _ b: RGB) -> Double {
    func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    func lum(_ p: RGB) -> Double { 0.2126 * linear(p.r) + 0.7152 * linear(p.g) + 0.0722 * linear(p.b) }
    let (la, lb) = (lum(a), lum(b))
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}
