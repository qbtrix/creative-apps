// HaloHistoryAreaTests.swift (autosave-history HA-3, packet
// docs/blueprints/halo/features/autosave-history.md): the History button by
// the transport and the panel it shows. On the real window (HostedHaloWindow,
// `keyed` on live services with Ball's x typed at four frames), pressing
// `halo.history.show` shows the panel and pressing it again hides it, so a
// dead button fails; pressing a row sends exactly one jump to the window's
// `jumpHistory(_:)` (HaloWindow.historyJumps, a debug-only counter), so a
// doubled jump fails. Over a host that owns the project and can undo, the
// panel follows the undo: the undone step reads "not applied" and the
// selection moves to the step before it, with no jump sent. Presses go
// through the accessibility tree, as VoiceOver's do. Nested in
// BodyCountSuites: it reads a process-global debug counter. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct HaloHistoryAreaTests {
        /// `keyed` on live services with Ball selected and its x typed at frames 0..<`edits`: "New Project" and
        /// `edits` "Change Position X" steps, the last current.
        static func edited(_ edits: Int) throws -> HaloProject {
            var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" })
            project.selectLayer(ball.id)
            for frame in 0..<edits {
                project.scrub(to: frame)
                project.setProperty(.x, text: "\(100 + frame * 10)")
            }
            return project
        }

        @Test(.timeLimit(.minutes(2))) func theButtonTogglesThePanel() async throws {
            let hosted = try await HostedHaloWindow(try Self.edited(4))
            defer { hosted.close() }
            #expect(hosted.frame(of: "suite.history") == nil, "the panel shows before the History button is pressed")
            let shown = try await hosted.press("halo.history.show")
            #expect(shown, "no halo.history.show button by the transport")
            #expect(hosted.frame(of: "suite.history") != nil, "the History button didn't show the panel")
            let hidden = try await hosted.press("halo.history.show")
            #expect(hidden, "the History button can't be pressed a second time")
            #expect(hosted.frame(of: "suite.history") == nil, "the History button didn't hide the panel")
        }

        /// #5844, H-J13: at the journeys' 1000 by 640 window the shown panel sits over the viewer, clear of its
        /// own button, the status row and the timeline, so the button still hides it and the playhead stays readable.
        @Test(.timeLimit(.minutes(2))) func thePanelCoversNeitherItsButtonNorTheTimeline() async throws {
            let hosted = try await HostedHaloWindow(try Self.edited(4), size: CGSize(width: 1000, height: 640))
            defer { hosted.close() }
            let shown = try await hosted.press("halo.history.show")
            #expect(shown, "no halo.history.show button by the transport")
            let panel = try #require(hosted.frame(of: "suite.history"), "the History button didn't show the panel")
            for id in ["halo.history.show", "halo.timeline", "halo.transport.play"] {
                let other = try #require(hosted.frame(of: id), "no \(id) with the panel shown")
                #expect(!panel.intersects(other), "the History panel \(panel) covers \(id) \(other)")
            }
            let canvas = try #require(hosted.frame(of: "halo.viewer"), "no halo.viewer")
            #expect(canvas.contains(panel), "the History panel \(panel) spills out of the viewer \(canvas)")
            // The real window as drawn, for review: halo-history-panel-window-light/dark.png.
            for (scheme, name) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
                hosted.window.appearance = NSAppearance(named: scheme)
                try await Task.sleep(for: .milliseconds(300))
                try Self.write(hosted.host, name: "halo-history-panel-window-\(name)")
            }
        }

        /// `view` as drawn, a PNG in .build/snapshots.
        static func write(_ view: NSView, name: String) throws {
            guard let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw SnapshotError.render(name) }
            view.cacheDisplay(in: view.bounds, to: image)
            guard let png = image.representation(using: .png, properties: [:]) else { throw SnapshotError.encode(name) }
            let folder = try packageRoot().appending(path: ".build/snapshots")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: folder.appending(path: "\(name).png"))
        }

        @Test(.timeLimit(.minutes(2))) func aRowPressSendsOneJump() async throws {
            let hosted = try await HostedHaloWindow(try Self.edited(4))
            defer { hosted.close() }
            let shown = try await hosted.press("halo.history.show")
            #expect(shown, "no halo.history.show button by the transport")
            #if DEBUG
            let before = HaloWindow.historyJumps
            #endif
            let pressed = try await hosted.press("suite.history.row.2")
            #expect(pressed, "the panel has no row 2 to press")
            #if DEBUG
            let sent = HaloWindow.historyJumps - before
            #expect(sent == 1, "one row press sent \(sent) jumps")
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func thePanelFollowsUndo() async throws {
            let jumps = HaloJumpCount()
            let w = RenderBudgetWindow(HaloHistoryAreaHost(model: try Self.edited(4), jumps: jumps))
            defer { w.close() }
            try await w.settle()
            _ = await w.element("suite.history.row.4")
            #expect(Self.label("suite.history.row.4", in: w)?.hasSuffix(", applied") == true, "step 4 isn't applied")
            #expect(Self.node("suite.history.row.4", in: w)?.isAccessibilitySelected?() == true, "step 4 isn't selected")
            let undid = Self.node("test.undo", in: w)?.accessibilityPerformPress?() ?? false
            #expect(undid, "the host has no Undo button")
            try await w.settle()
            #expect(Self.label("suite.history.row.4", in: w)?.hasSuffix("not applied") == true, "the panel didn't follow the undo")
            #expect(Self.node("suite.history.row.3", in: w)?.isAccessibilitySelected?() == true, "the selection didn't follow the undo")
            #expect(jumps.count == 0, "an undo sent \(jumps.count) jumps")
        }

        static func node(_ identifier: String, in w: RenderBudgetWindow<HaloHistoryAreaHost>) -> AnyObject? {
            RenderBudgetHistoryPanelTests.node(identifier, in: w.host)
        }

        static func label(_ identifier: String, in w: RenderBudgetWindow<HaloHistoryAreaHost>) -> String? {
            node(identifier, in: w)?.accessibilityLabel?() ?? nil
        }
    }
}

@MainActor final class HaloJumpCount {
    var count = 0
}

/// HaloHistoryArea over a column with an Undo button, the panel shown: the project is this host's, as it is
/// the window's, and each body hands the area the project as it now is.
struct HaloHistoryAreaHost: View {
    @State var model: HaloProject
    let jumps: HaloJumpCount
    @State private var shelf = HaloHistoryShelf(shown: true)

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Button("Undo") { model.undo() }
                .accessibilityIdentifier("test.undo")
            Spacer()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay { HaloHistoryOverlay(model: model) }
        .modifier(HaloHistoryArea(model: model) { _ in jumps.count += 1 })
        .environment(\.haloHistoryShelf, shelf)
    }
}
#endif
