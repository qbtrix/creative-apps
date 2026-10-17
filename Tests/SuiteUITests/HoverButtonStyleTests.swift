// HoverButtonStyleTests.swift: which surface a floating button shows for its
// pointer and press state (HoverButtonLevel, which HoverButtonStyle and the
// grid cells read). Pressed wins over hover; a disabled button never lights
// up. No SwiftUI import. macOS only, like the rest of SuiteUI.
import SuiteUI
import Testing

@Test func restingButtonShowsNoSurface() {
    #expect(HoverButtonLevel.resolve(hovering: false, pressed: false) == .rest)
}

@Test func hoverLightsTheButton() {
    #expect(HoverButtonLevel.resolve(hovering: true, pressed: false) == .hover)
}

@Test func pressedWinsOverHover() {
    #expect(HoverButtonLevel.resolve(hovering: true, pressed: true) == .pressed)
    #expect(HoverButtonLevel.resolve(hovering: false, pressed: true) == .pressed)
}

@Test func disabledButtonNeverLightsUp() {
    #expect(HoverButtonLevel.resolve(hovering: true, pressed: true, enabled: false) == .rest)
}
