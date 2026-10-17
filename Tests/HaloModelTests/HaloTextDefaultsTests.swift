// HaloTextDefaultsTests.swift (#2176, #2178): a new text layer's default
// color reads on the white artboard (WCAG contrast of at least 4.5:1), other
// kinds keep theirs, and the text edits refuse through the shared selection
// lookup (`.noComposition`, `.noLayerSelected` under their own control).
// Linux and macOS.
import Foundation  // pow, for the WCAG transfer curve
import HaloModel
import Testing

/// WCAG relative luminance of an sRGB color with components in 0...1.
private func luminance(_ c: HaloLayerColor) -> Double {
    func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
}

/// WCAG contrast ratio between two colors.
private func contrast(_ a: HaloLayerColor, _ b: HaloLayerColor) -> Double {
    let (la, lb) = (luminance(a), luminance(b))
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

private let artboard = HaloLayerColor(red: 1, green: 1, blue: 1)

@Test func aNewTextLayerReadsOnTheWhiteArtboard() throws {
    #expect(contrast(HaloLayerKind.text.defaultColor, artboard) >= 4.5)
    var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
    project.newLayer(.text)
    let color = try #require(project.selectedLayerColor)
    #expect(contrast(color, artboard) >= 4.5)
}

@Test func otherKindsKeepTheirDefaultColors() {
    #expect(HaloLayerKind.solid.defaultColor == HaloLayerColor(red: 0.85, green: 0.33, blue: 0.25))
    #expect(HaloLayerKind.shape.defaultColor == HaloLayerColor(red: 0.25, green: 0.55, blue: 0.9))
    #expect(HaloLayerKind.null.defaultColor == HaloLayerColor(red: 0.6, green: 0.6, blue: 0.6))
}

@Test func textEditsWithoutALayerOrCompositionAreRefused() throws {
    var empty = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
    empty.setText("Hello")
    #expect(empty.refusal == HaloRefusal(control: "halo.inspector.text.string", message: HaloEditError.noLayerSelected.message))
    empty.setFontSize(96)
    #expect(empty.refusal == HaloRefusal(control: "halo.inspector.text.size", message: HaloEditError.noLayerSelected.message))
    #expect(empty.history.undo.isEmpty)

    var none = HaloProject(services: .fake)
    none.setText("Hello")
    #expect(none.refusal == HaloRefusal(control: "halo.inspector.text.string", message: HaloEditError.noComposition.message))
    none.setFontSize(96)
    #expect(none.refusal == HaloRefusal(control: "halo.inspector.text.size", message: HaloEditError.noComposition.message))
    #expect(none.history.undo.isEmpty)
}
