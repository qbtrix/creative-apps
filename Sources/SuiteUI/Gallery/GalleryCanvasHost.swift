// GalleryCanvasHost.swift: the gallery's `canvas-host` page: CanvasHost over
// FakeCanvasContent; the log's one observed change is on `endDrag`.
import Observation
import SwiftUI

enum GalleryCanvasHost {
    static let name = "canvas-host"

    @MainActor static let pages: GalleryPages = [name: { AnyView(CanvasHostPage()) }]
}

/// The page's delegate: counts drags; logs each finished drag and key.
@MainActor @Observable final class CanvasHostLog: CanvasInputDelegate {
    private(set) var lines = ["Drag on the canvas."]
    @ObservationIgnored private(set) var drags = 0
    @ObservationIgnored private(set) var endDrags = 0
    @ObservationIgnored private var samples = 0

    func drag(from: CGPoint, to: CGPoint, pressure: Double, modifiers: EventModifiers) { (drags, samples) = (drags + 1, samples + 1) }
    func hover(_ point: CGPoint?) {}
    func key(_ press: KeyPress) -> KeyPress.Result { log("key \(press.characters)"); return .handled }
    func endDrag() {
        endDrags += 1
        log("endDrag after \(samples) samples")
        samples = 0
    }

    private func log(_ line: String) { lines = Array((lines + [line]).suffix(3)) }
}

/// CanvasHost on the fake 4096 x 2160 document, its event log under it.
struct CanvasHostPage: View {
    #if DEBUG
    static var bodyRuns = 0
    #endif
    @State private var log: CanvasHostLog

    init(log: CanvasHostLog = CanvasHostLog()) { _log = State(initialValue: log) }

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(spacing: 0) {
            CanvasHost(content: FakeCanvasContent(), delegate: log)
            Text(log.lines.joined(separator: "\n")).font(SuiteFont.caption).foregroundStyle(SuiteColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(SuiteSpacing.s)
                .accessibilityIdentifier("suite.gallery.canvas-host.log")
        }
    }
}
