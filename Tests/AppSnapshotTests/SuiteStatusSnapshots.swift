// SuiteStatusSnapshots.swift: ViewerStatusBar's pills under a viewer: zoom and
// size alone; with plain trailing pills and a View menu; with a toggle pill
// on and off and a warning pill; and with no document (the "–" zoom), on the
// editor panel, in Light and Dark. Writes suiteui-status-light.png and
// suiteui-status-dark.png, and checks the same sheet against
// Golden/chrome/status-<appearance>.png in the four appearances (EC-12
// commits the baselines). The bar's zoom and size text come from its
// StatusPillComposing, PillStyle maps onto StatusPillStyle, each style has its
// color and symbol (an error is stateError, not a warning), and a pill that
// acts registers the reason its tooltip shows. Only pills that need attention
// are tinted: the zoom pill reads grey like the size pill (#3136). macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteStatusSnapshots {
    @Test func statusPills() throws {
        try snapshot(StatusSheet(), name: "suiteui-status-light", scheme: .light)
        try snapshot(StatusSheet(), name: "suiteui-status-dark", scheme: .dark)
    }

    @Test func statusGolden() {
        let size = CGSize(width: 800, height: 260)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(StatusSheet(), size: size, name: "status", area: "chrome", appearance: appearance)
        }
    }

    @Test func theComposerWritesTheZoomAndSizeText() {
        let size = PlaneExtent(width: 1920, height: 1080)
        let composed = ViewerStatusBar(zoom: 2, documentSize: size, composing: LetterPills())
        #expect(composed.zoomText == "x")
        #expect(composed.sizeText == "y")
        let live = ViewerStatusBar(zoom: 2, documentSize: size)
        #expect(live.zoomText == ViewerZoom.percentText(2))
        #expect(live.sizeText == "1920 × 1080")
        let named = ViewerStatusBar(zoom: 0.51, size: "No file open")
        #expect(named.zoomText == ViewerZoom.percentText(0.51))
        #expect(named.sizeText == "No file open")
    }

    /// A viewer with no zoom (Library's grid) hides the zoom pill (#1184).
    @Test func aNilZoomDrawsNoZoomPill() {
        #expect(ViewerStatusBar(zoom: nil, size: "24 photos").zoomText == nil)
        #expect(ViewerStatusBar(zoom: 1, size: "800 × 600 px").zoomText == ViewerZoom.percentText(1))
    }

    /// Only a pill that needs attention is tinted; the rest, the zoom pill too, read grey (#3136). Both
    /// pills hold "100%", so their darkest glyph pixels match unless one draws in a different ink.
    @Test func theZoomPillReadsGreyLikeTheSizePill() throws {
        let text = ViewerZoom.percentText(1)
        let width: CGFloat = 300
        let bar = ViewerStatusBar(zoom: 1, size: text).frame(width: width)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let image = try #require(render(bar, scheme: .light))
        let pill = NSHostingView(rootView: StatusPillFace(.plain) { Text(text) }.fixedSize()).fittingSize.width
        let sizeEnd = width - SuiteSpacing.s
        let zoomEnd = sizeEnd - pill - SuiteSpacing.pillGap
        /// The darkest luminance inside one pill, 2 pt in from its edges.
        func darkest(endingAt end: CGFloat) -> CGFloat {
            var low: CGFloat = 1
            for x in Int(end - pill + 2)..<Int(end - 2) {
                for y in 2..<Int(SuiteSize.pillHit) {
                    guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                    low = min(low, 0.299 * color.redComponent + 0.587 * color.greenComponent + 0.114 * color.blueComponent)
                }
            }
            return low
        }
        let (zoom, size) = (darkest(endingAt: zoomEnd), darkest(endingAt: sizeEnd))
        #expect(size < 0.8, "no glyphs in the size pill (darkest \(size)): the crop missed it")
        #expect(abs(zoom - size) < 0.08, "the zoom pill's ink (darkest \(zoom)) isn't the size pill's grey (\(size))")
    }

    @Test func everyPillStyleMaps() {
        #expect(StatusPillStyle(PillStyle.plain) == .plain)
        #expect(StatusPillStyle(PillStyle.toggle(isOn: true)) == .toggle(isOn: true))
        #expect(StatusPillStyle(PillStyle.toggle(isOn: false)) == .toggle(isOn: false))
        #expect(StatusPillStyle(PillStyle.warning) == .warning)
    }

    /// A failed save or render is an error, not a warning: stateError with an
    /// exclamation circle (design.md State colors, #3167).
    @Test func anErrorPillDrawsInTheErrorColor() {
        #expect(StatusPillStyle.error.symbol == "exclamationmark.circle.fill")
        #expect(StatusPillStyle.error.foreground == SuiteColor.stateError)
        #expect(StatusPillStyle.error.fill == SuiteColor.errorTint)
        #expect(StatusPillStyle.warning.symbol == "exclamationmark.triangle.fill")
        #expect(StatusPillStyle.warning.foreground == SuiteColor.stateWarning)
        #expect(StatusPillStyle.plain.symbol == nil)
        #expect(StatusPillStyle.plain.foreground == SuiteColor.textSecondary)
        #expect(StatusPillStyle.toggle(isOn: true).foreground == SuiteColor.accentText)
    }

    @Test func aTogglePillRegistersTheReasonItsTooltipShows() throws {
        let onion = StatusPillControl(id: "suite.status.onion", help: "Onion skin", reason: nil) {}
        let loop = StatusPillControl(id: "suite.status.loop", help: "Loop", reason: "Nothing to loop.") {}
        let bar = ViewerStatusBar(zoom: 1, documentSize: PlaneExtent(width: 800, height: 600)) {
            Text("Onion").statusPill(.toggle(isOn: true), id: onion.id, help: onion.help, action: onion.action)
            Text("Loop").statusPill(.toggle(isOn: false), id: loop.id, help: loop.help, reason: loop.reason, action: loop.action)
            Text("Preview data").statusPill(.warning)
        }
        let store = SuiteControlStore()
        _ = try #require(render(bar.environment(\.suiteControlStore, store), scheme: .light))
        let entries = store.inventory.document().controls
        #expect(entries.map(\.id) == [loop.id, onion.id])
        #expect(entries.first?.enabled == false)
        #expect(entries.first?.reason == loop.tooltip)
        #expect(entries.last?.enabled == true)
        #expect(entries.last?.reason == nil)
        #expect(onion.tooltip == "Onion skin")
        #expect(store.inventory.violations().isEmpty)
    }
}

/// A composer whose pills are letters, so a test can tell the bar's text came from it.
private struct LetterPills: StatusPillComposing {
    func pills(zoom: Double, documentSize: PlaneExtent, trailing: [StatusPill]) -> [StatusPill] {
        [StatusPill(text: "x"), StatusPill(text: "y")] + trailing
    }
}

private struct StatusSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            ViewerStatusBar(zoom: 0.51, size: "1920 × 1080 px")
            ViewerStatusBar(zoom: 1, size: "800 × 600 px") {
                Text("Brush")
                Text("12 ms render")
                Menu("View") { Button("Fit") {} }.menuStyle(.button).buttonStyle(.plain)
            }
            ViewerStatusBar(zoom: 2, size: "1080 × 1080 px") {
                Text("Onion").statusPill(.toggle(isOn: true))
                Text("Loop").statusPill(.toggle(isOn: false))
                Text("Preview data").statusPill(.warning)
            }
            ViewerStatusBar(zoom: 0, size: "No file open")
        }
        .frame(width: 720)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.canvasSurround)
    }
}
