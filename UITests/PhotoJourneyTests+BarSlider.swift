// PhotoJourneyTests+BarSlider.swift: how a Photo journey sets a SuiteUI bar
// slider (InspectorSliderRow: the layer Opacity, the tone rows, the export
// sheet's Quality, a filter's Radius) as a person does. XCUI's
// adjust(toNormalizedSliderPosition:) can't drive one: the bar's accessibility
// slider has no orientation, so XCUI fails to synthesize the drag (#3105), and
// a bar scrubs from where it is instead of jumping to the pointer, so no
// normalized position names a value. To land on a value, click the bar and
// type it, then Tab away to commit (Return would also press a sheet's default
// button). To push it to an end, drag past the end: the value clamps.
import XCTest

extension Journey {
    /// Clicks `bar`, types `value` into the field the click opens and Tabs away to commit it.
    func enter(_ value: String, in bar: XCUIElement) {
        bar.click()
        let field = element("suite.scrub.typing")
        XCTAssert(field.waitForExistence(timeout: 5), "clicking \(bar.label) opened no field to type in")
        field.click()
        app.typeKey(.rightArrow, modifierFlags: .command)
        for _ in 0..<12 { app.typeKey(.delete, modifierFlags: []) }
        app.typeText(value)
        app.typeKey(.tab, modifierFlags: [])
    }

    /// Drags `bar` sideways from its middle by `fraction` of its width.
    func scrub(_ bar: XCUIElement, by fraction: CGFloat) {
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + fraction, dy: 0.5)))
    }
}
