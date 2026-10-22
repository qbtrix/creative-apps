// HaloLayoutTests.swift: Halo's layout rules L3 to L5 (blueprint halo 7.3;
// packet docs/blueprints/halo/features/core-loop.md, Quality tests, CL-11).
// L3: HaloTimelineView drawn through SnapshotHost at 600, 900 and 1400 pt on
// the `keyed` fixture; at frame 0, last / 2 and last the playhead's 2 pt
// accent line, found in the pixel row 4 pt under the ruler, is centred within
// 1 pt of the lane origin (name column, divider, the strip's s inset) plus
// frame × frame width. L4: HaloLayerInspector with Ball selected at frame 12,
// hosted at the inspector's minimum, ideal and maximum widths in a window far
// off every screen with accessibility on and no control focused; every
// `halo.inspector.row.<raw>` bar starts and ends within 0.5 pt of the others, every
// `halo.inspector.key.<raw>` stopwatch starts within 0.5 pt of the others
// (one column), and each bar is wide enough for its title, the s gap and its
// value inside its m padding. L5: HaloViewer hosted at the content minimum;
// all six `halo.transport.*` controls show, left of the status row's zoom,
// size, timecode and layer pills; none overlaps another by more than 0 pt or
// leaves the row, and the timecode shows at its full width. A miss is a `finding` on
// the view's owner, not a fix in the test. macOS only.
#if canImport(AppKit)
import AppKit
import CoreGraphics
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloLayoutTests {
    /// L3's timeline widths, in points.
    nonisolated static let timelineWidths: [CGFloat] = [600, 900, 1400]
    /// L3: the playhead's distance from its frame's x, at most.
    nonisolated static let playheadTolerance: CGFloat = 1
    /// L4: the TRANSFORM bars' edges across rows, at most.
    nonisolated static let barTolerance: CGFloat = 0.5
    /// L5: the status row's transport and pills overlap, at most.
    nonisolated static let statusOverlap: CGFloat = 0

    /// `-HaloSample keyed` on fake services: Ball keyed at 0, 12 and 24 over Floor.
    private func keyed() throws -> HaloProject {
        HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
    }

    // MARK: L3

    /// L3: the playhead on its frame at 600, 900 and 1400 pt (≤ 1 pt).
    @Test func playheadOnItsFrame() throws {
        var project = try keyed()
        let last = try #require(project.selectedComposition?.lastFrame, "no composition")
        #expect(last > 0, "the composition has one frame")
        let layout = HaloTimelineView.layout
        for width in Self.timelineWidths {
            for frame in [0, last / 2, last] {
                project.scrub(to: frame)
                let comp = try #require(project.selectedComposition)
                #expect(comp.playheadFrame == frame)
                let frameWidth = comp.frameWidth(toFit: layout.laneFitWidth(width: Double(width)))
                let origin = layout.labelColumn + layout.divider + Double(SuiteSpacing.s)
                let expected = CGFloat(origin + Double(frame) * frameWidth)
                let image = try #require(SnapshotHost(appearance: .light).image(
                    HaloTimelineView(model: project).frame(maxHeight: .infinity, alignment: .top),
                    size: CGSize(width: width, height: 240)))
                let found = Self.accentLine(in: image, nearX: expected, y: CGFloat(layout.ruler) + 4)
                let report = "L3 at \(width) pt, frame \(frame) of \(last): line at \(found.map { "\($0)" } ?? "none"), want \(expected)"
                print(report)
                let line = try #require(found, "\(report)")
                #expect(abs(line - expected) <= Self.playheadTolerance, "\(report)")
            }
        }
    }

    /// The centre, in points, of the accent run in the pixel row `y` (points)
    /// nearest `nearX`; nil when that row has no accent pixel.
    private static func accentLine(in image: RGBAImage, nearX: CGFloat, y: CGFloat) -> CGFloat? {
        let scale = SnapshotHost.scale
        let row = Int((y * scale).rounded())
        guard row >= 0, row < image.height else { return nil }
        let accent = SuitePalette.accent.light
        let want = [Int((accent >> 16) & 0xFF), Int((accent >> 8) & 0xFF), Int(accent & 0xFF)]
        func isAccent(_ x: Int) -> Bool {
            let i = (row * image.width + x) * 4
            guard i + 2 < image.bytes.count else { return false }
            return (0..<3).allSatisfy { abs(Int(image.bytes[i + $0]) - want[$0]) <= 24 }
        }
        var runs: [ClosedRange<Int>] = []
        var start: Int?
        for x in 0...image.width {
            let hit = x < image.width && isAccent(x)
            if hit, start == nil { start = x }
            if !hit, let first = start {
                runs.append(first...(x - 1))
                start = nil
            }
        }
        let centres = runs.map { CGFloat($0.lowerBound + $0.upperBound + 1) / 2 / scale }
        return centres.min { abs($0 - nearX) < abs($1 - nearX) }
    }

    // MARK: L4

    /// L4: TRANSFORM bars aligned at the inspector's minimum, ideal and maximum widths (≤ 0.5 pt).
    @Test(.timeLimit(.minutes(2))) func transformBarsAlign() async throws {
        var project = try keyed()
        let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" }, "no Ball")
        project.selectLayer(ball.id)
        project.scrub(to: 12)
        let rows = project.propertyRows
        #expect(rows.count == HaloProperty.allCases.count, "TRANSFORM shows \(rows.count) rows")
        let widths = SuiteSize.inspectorWidth
        for width in [widths.min, widths.ideal, widths.max] {
            let host = try await AXHost(
                HaloLayerInspector(model: project).frame(width: width, alignment: .topLeading).background(SuiteColor.panel),
                size: CGSize(width: width, height: 1000))
            defer { host.close() }
            let frames = host.frames(prefix: "halo.inspector.")
            var bars: [(String, CGRect)] = [], keys: [CGRect] = []
            for row in rows {
                let raw = row.property.rawValue
                let bar = try #require(frames["halo.inspector.row.\(raw)"], "no bar for \(raw) at \(width) pt")
                bars.append((row.property.title, bar))
                keys.append(try #require(frames["halo.inspector.key.\(raw)"], "no stopwatch for \(raw) at \(width) pt"))
            }
            let report = "L4 at \(width) pt: bars \(bars.map { "\($0.0) \(Self.span($0.1))" }.joined(separator: ", ")); stopwatches at x \(keys.map { "\($0.minX)" }.joined(separator: ", "))"
            print(report)
            #expect(Self.spread(bars.map(\.1.minX)) <= Self.barTolerance, "bars start apart: \(report)")
            #expect(Self.spread(bars.map(\.1.maxX)) <= Self.barTolerance, "bars end apart: \(report)")
            #expect(Self.spread(keys.map(\.minX)) <= Self.barTolerance, "keyframe buttons out of one column: \(report)")
            for (row, bar) in zip(rows, bars.map(\.1)) {
                let title = row.property.title
                let label = HStack(spacing: SuiteSpacing.s) {
                    Text(verbatim: title).font(SuiteFont.inspectorLabel)
                    Text(verbatim: row.text).font(SuiteFont.inspectorValue)
                }
                let need = Self.fittingWidth(label) + 2 * SuiteSpacing.m
                #expect(bar.width >= need - Self.barTolerance,
                    "\(title) truncates at \(width) pt: its bar is \(bar.width) pt, the label and \(row.text) need \(need)")
            }
        }
    }

    // MARK: L5

    /// L5: the status row never overlaps at the content minimum (0 pt).
    @Test(.timeLimit(.minutes(2))) func statusRowNeverOverlaps() async throws {
        var project = try keyed()
        project.scrub(to: 12)
        let comp = try #require(project.selectedComposition)
        let size = SuiteSize.contentMinimum
        let host = try await AXHost(HaloViewer(model: project), size: size)
        defer { host.close() }
        var items: [(String, CGRect)] = []
        // Every transport control stays at the minimum, so a mouse can still play and step (#4272).
        for id in ["start", "previous", "play", "next", "end", "loop"].map({ "halo.transport.\($0)" }) {
            let frame = try #require(host.frames(prefix: id)[id], "\(id) is gone at \(size.width) pt")
            items.append((id, frame))
        }
        let texts: [(String, (String) -> Bool)] = [
            ("zoom", { $0.hasPrefix("Zoom ") }), ("size", { $0 == comp.sizeText }),
            ("timecode", { $0 == comp.statusTimecode }), ("layers", { $0 == comp.layerSummary }),
        ]
        for (name, matches) in texts {
            if let frame = host.frame(text: matches) { items.append((name, frame)) }
        }
        let report = "L5 at \(size.width) pt: \(items.map { "\($0.0) \(Self.span($0.1))" }.joined(separator: ", "))"
        print(report)
        #expect(items.contains { $0.0 == "zoom" } && items.contains { $0.0 == "size" }, "the pills weren't found: \(report)")
        for (index, (name, frame)) in items.enumerated() {
            #expect(frame.minX >= -Self.barTolerance && frame.maxX <= size.width + Self.barTolerance,
                "\(name) runs out of the row: \(report)")
            for (other, next) in items.dropFirst(index + 1) {
                let across = min(frame.maxX, next.maxX) - max(frame.minX, next.minX)
                let down = min(frame.maxY, next.maxY) - max(frame.minY, next.minY)
                // A thousandth of a point is rounding between edge-to-edge squares, not overlap.
                let overlap = across > Self.statusOverlap + 0.001 && down > Self.statusOverlap + 0.001
                #expect(!overlap, "\(name) and \(other) overlap by \(across) pt: \(report)")
            }
        }
        // Transport left, pills right.
        let transportEnd = items.filter { $0.0.hasPrefix("halo.transport.") }.map(\.1.maxX).max() ?? 0
        let pillsStart = items.filter { !$0.0.hasPrefix("halo.transport.") }.map(\.1.minX).min() ?? 0
        #expect(transportEnd <= pillsStart + Self.statusOverlap + 0.001, "the transport isn't left of the pills: \(report)")
        let timecode = try #require(items.first { $0.0 == "timecode" }?.1, "no timecode at the content minimum: \(report)")
        let full = Self.fittingWidth(Text(verbatim: comp.statusTimecode).font(SuiteFont.pill))
        #expect(timecode.width >= full - Self.barTolerance, "the timecode is \(timecode.width) pt of its \(full): \(report)")
    }

    // MARK: Helpers

    /// The width `view` takes on one line at its ideal size.
    private static func fittingWidth(_ view: some View) -> CGFloat {
        NSHostingView(rootView: view.lineLimit(1).fixedSize()).fittingSize.width
    }

    /// How far apart the largest and smallest of `values` are; 0 when empty.
    private static func spread(_ values: [CGFloat]) -> CGFloat {
        guard let low = values.min(), let high = values.max() else { return 0 }
        return high - low
    }

    private static func span(_ frame: CGRect) -> String {
        "\(frame.minX)...\(frame.maxX) × \(frame.minY)...\(frame.maxY)"
    }
}

/// A view in a borderless window placed far off every screen, accessibility
/// on, so its identified elements report their frames (window points).
@MainActor private final class AXHost {
    private let window: NSWindow
    private let root: NSView

    init(_ view: some View, size: CGSize) async throws {
        for name in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: name))
        }
        let bounds = CGRect(origin: .zero, size: size)
        root = NSHostingView(rootView: view.frame(width: size.width, height: size.height, alignment: .topLeading))
        root.frame = bounds
        window = NSWindow(contentRect: bounds, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = root
        window.setFrameOrigin(NSPoint(x: -24_000, y: -24_000))
        window.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(500))
        // The window's first focusable control takes focus, and its focus effect grows its accessibility
        // frame by 3 pt on every side (L4's first bar read 9...191 against 12...188). The rules measure
        // layout, not focus, so no control keeps it.
        window.makeFirstResponder(nil)
        try await Task.sleep(for: .milliseconds(300))
    }

    func close() { window.close() }

    /// Each element whose identifier starts with `prefix`, by identifier (the first of a pair).
    func frames(prefix: String) -> [String: CGRect] {
        var result: [String: CGRect] = [:]
        for element in Self.walk(root) {
            if let id = Self.text(element, "accessibilityIdentifier"), id.hasPrefix(prefix), result[id] == nil,
                let frame = element.accessibilityFrame?() {
                result[id] = window.convertFromScreen(frame)
            }
        }
        return result
    }

    /// The first element whose label or value `matches`, as text.
    func frame(text matches: (String) -> Bool) -> CGRect? {
        for element in Self.walk(root) {
            let label = Self.text(element, "accessibilityLabel")
            let value = Self.text(element, "accessibilityValue")
            guard [label, value].contains(where: { $0.map(matches) ?? false }),
                let frame = element.accessibilityFrame?()
            else { continue }
            return window.convertFromScreen(frame)
        }
        return nil
    }

    /// The attribute `getter` answers on `element` when it is text; nil for any other type. Read
    /// untyped, then checked: a toggle answers its value with an NSNumber (the transport's Loop
    /// checkbox, 1), and reading that through `AnyObject`'s `String?` signature bridges it
    /// unconditionally and traps the whole test process.
    private static func text(_ element: AnyObject, _ getter: String) -> String? {
        let selector = NSSelectorFromString(getter)
        guard let object = element as? NSObject, object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue() as? String
    }

    private static func walk(_ element: Any) -> [AnyObject] {
        let object = element as AnyObject
        let children = (object.accessibilityChildren?() ?? nil) ?? []
        return children.reduce(into: [object]) { $0 += walk($1) }
    }
}
#endif
