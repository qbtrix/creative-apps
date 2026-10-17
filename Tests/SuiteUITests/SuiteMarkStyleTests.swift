// SuiteMarkStyleTests.swift: an icon mark (a rating star, a color dot) lights
// its fill on hover or press, and never while disabled (docs/design.md: every
// control shows hover and pressed states). macOS only.
import SuiteUI
import Testing

@MainActor @Test func aHoveredOrPressedMarkIsLit() {
    #expect(SuiteMarkStyle.highlight(hovering: true, pressed: false, enabled: true))
    #expect(SuiteMarkStyle.highlight(hovering: false, pressed: true, enabled: true))
}

@MainActor @Test func aRestingOrDisabledMarkIsNotLit() {
    #expect(!SuiteMarkStyle.highlight(hovering: false, pressed: false, enabled: true))
    #expect(!SuiteMarkStyle.highlight(hovering: true, pressed: false, enabled: false))
    #expect(!SuiteMarkStyle.highlight(hovering: false, pressed: true, enabled: false))
}
