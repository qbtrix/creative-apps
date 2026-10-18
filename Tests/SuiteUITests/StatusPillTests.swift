// StatusPillTests.swift: SuiteStatusPills, the status bar's live pill rule
// (EC-6b). The zoom reads through ViewerZoom.percentText and a zoom that
// isn't a positive number reads "–"; each side rounds to the nearest whole
// unit; the trailing pills keep their order and style. No SwiftUI. macOS only.
import SuiteUI
import Testing

private let hd = PlaneExtent(width: 1920, height: 1080)

private func texts(zoom: Double, size: PlaneExtent = hd, trailing: [StatusPill] = []) -> [String] {
    SuiteStatusPills().pills(zoom: zoom, documentSize: size, trailing: trailing).map(\.text)
}

@Test func statusZoomReadsAsAWholePercent() {
    #expect(texts(zoom: 2).first == "200%")
    #expect(texts(zoom: 2).first == ViewerZoom.percentText(2))
    #expect(texts(zoom: 0.505).first == "51%")
}

@Test func aZoomThatIsNotAPositiveNumberReadsADash() {
    for zoom in [Double.nan, .infinity, -.infinity, 0, -1] {
        #expect(texts(zoom: zoom).first == "–")
    }
}

@Test func sizeReadsWidthByHeightRoundedToWholeUnits() {
    #expect(texts(zoom: 1)[1] == "1920 × 1080")
    #expect(texts(zoom: 1, size: PlaneExtent(width: 1919.6, height: 1079.4))[1] == "1920 × 1079")
    #expect(texts(zoom: 1, size: PlaneExtent(width: 0.5, height: 99.5))[1] == "1 × 100")
    #expect(texts(zoom: 1, size: PlaneExtent(width: .infinity, height: 1e300))[1] == "0 × 0")
}

@Test func trailingPillsKeepTheirOrderAndStyle() {
    let trailing = [
        StatusPill(text: "Onion", style: .toggle(isOn: true)), StatusPill(text: "Low memory", style: .warning),
        StatusPill(text: "Loop", style: .toggle(isOn: false)),
    ]
    let pills = SuiteStatusPills().pills(zoom: 1, documentSize: hd, trailing: trailing)
    #expect(pills.map(\.text) == ["100%", "1920 × 1080", "Onion", "Low memory", "Loop"])
    #expect(pills.map(\.style) == [.plain, .plain, .toggle(isOn: true), .warning, .toggle(isOn: false)])
}
