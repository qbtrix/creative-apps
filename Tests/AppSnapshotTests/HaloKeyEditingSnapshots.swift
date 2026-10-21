// HaloKeyEditingSnapshots.swift (key-editing KE-5): the packet's four screens on the
// `parented` fixture (Rig keyed on x at 0 and 47, Ball at 0, 12 and 24, Floor
// unkeyed, top first). HaloViewer with Ball's key at 0 picked and Rig's at 0
// added with Shift, so keys on two lanes draw picked; HaloViewer after Select
// All Keys, every key of every lane picked; HaloTimelineView hosted in a
// 1440 x 900 window, the playhead scrubbed to 36 (at 0 its 16 pt grab band
// covers the key and the strip gives the press to the scrub, TL-22: #4150),
// with Ball's key at 0 pressed and dragged 6 frames right
// by real mouse events and held there, so the strip draws the step and the
// time pill over the grabbed key (the PNG is taken before the mouse-up; the
// recorder doesn't apply the commands, so the Model keeps the keys at 0); and
// the Animation menu's key items (HaloMenuTarget.item, as HaloAnimationMenu
// builds them) drawn as buttons, since the menu bar does not render here,
// Select All Keys enabled. Points come from HaloTimelineLayout and the Model's
// frame width plus the strip's 8 pt inset, as HaloTimelineClickTests finds
// them. Writes halo-timeline-keys-picked-across-, halo-timeline-all-picked-,
// halo-timeline-key-drag- and halo-animation-menu-select-all-{light,dark}.png.
// macOS only.
import AppKit
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloKeyEditingSnapshots {
    /// The `parented` fixture on fake services.
    private func parented() throws -> HaloProject {
        HaloProject(services: .fake, document: try #require(HaloFixtures.project("parented")))
    }

    /// The layer id of the timeline row named `name`.
    private func layer(_ name: String, in project: HaloProject) throws -> String {
        try #require(project.timelineRows.first { $0.name == name }?.id, "no \(name) row")
    }

    @Test func keysPickedAcrossLanes() throws {
        var project = try parented()
        let ball = try layer("Ball", in: project), rig = try layer("Rig", in: project)
        project.pickLaneKeys(layerID: ball, frame: 0, mode: .replace)
        project.pickLaneKeys(layerID: rig, frame: 0, mode: .extend)
        #expect(project.pickedFrames(of: ball) == [0] && project.pickedFrames(of: rig) == [0])
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(HaloViewer(model: project), name: "halo-timeline-keys-picked-across-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func allKeysPicked() throws {
        var project = try parented()
        project.selectAllKeys()
        #expect(project.pickedFrames(of: try layer("Ball", in: project)) == [0, 12, 24])
        #expect(project.pickedFrames(of: try layer("Rig", in: project)) == [0, 47])
        #expect(project.pickedFrames(of: try layer("Floor", in: project)).isEmpty)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(HaloViewer(model: project), name: "halo-timeline-all-picked-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func aKeyDragShowsTheTimePill() async throws {
        var project = try parented()
        let ball = try layer("Ball", in: project), rig = try layer("Rig", in: project)
        project.pickLaneKeys(layerID: ball, frame: 0, mode: .replace)
        project.pickLaneKeys(layerID: rig, frame: 0, mode: .extend)
        // Off every key: the playhead's grab band over Ball's key at 0 would take the press (#4150).
        project.scrub(to: Self.playhead)
        let row = try #require(project.timelineRows.firstIndex { $0.id == ball })
        let comp = try #require(project.selectedComposition)
        let layout = HaloTimelineView.layout
        let frameWidth = comp.frameWidth(toFit: layout.laneFitWidth(width: Self.size.width))
        for scheme in [ColorScheme.light, .dark] {
            let sent = KeyDragSent()
            let view = HaloTimelineView(model: project, perform: { sent.commands.append($0) })
                .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
                .background(SuiteColor.windowBackground)
                .environment(\.colorScheme, scheme)
                .environment(\.suiteSnapshotRendering, true)
            let w = RenderBudgetWindow(view, size: Self.size)
            defer { w.close() }
            w.window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            try await w.settle(400)
            /// `frame` on Ball's lane in window points (y up), from the strip's top-left.
            func point(_ frame: Double) -> CGPoint {
                let x = layout.labelColumn + layout.divider + Double(SuiteSpacing.s) + frame * frameWidth
                return CGPoint(x: x, y: Self.size.height - (layout.ruler + layout.lane * (Double(row) + 0.5)))
            }
            try await w.drag(from: point(0), samples: 24, release: false) { point(6 * Double($0) / 24) }
            try await w.settle(300)
            try Self.write(w, name: "halo-timeline-key-drag-\(scheme.name)")
            w.send(.leftMouseUp, at: point(6))
            try await w.settle(100)
            #expect(sent.commands.contains(.moveKeys(by: 6, dragStart: 0)), "the drag sent \(sent.commands)")
            #expect(sent.commands.last == .endKeyDrag, "the drag didn't end with endKeyDrag: \(sent.commands)")
        }
    }

    @Test func animationMenuSelectAll() throws {
        let project = try parented()
        let target = HaloMenuTarget(model: project, perform: { _ in })
        #expect(target.title(for: .selectAllKeys) == "Select All Keys" && target.help(for: .selectAllKeys) == nil)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(AnimationKeyItems(target: target), name: "halo-animation-menu-select-all-\(scheme.name)", scheme: scheme)
        }
    }

    static let size = CGSize(width: 1440, height: 900)
    /// Where the key drag's playhead sits: on no key of `parented`, far from the drag's 0 to 6.
    static let playhead = 36

    /// The hosted window's view as a 1440 × 900 PNG in .build/snapshots, as `snapshot` writes one.
    static func write<V: View>(_ w: RenderBudgetWindow<V>, name: String) throws {
        let host = w.host
        guard let image = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw SnapshotError.render(name) }
        host.cacheDisplay(in: host.bounds, to: image)
        guard let png = image.representation(using: .png, properties: [:]) else { throw SnapshotError.encode(name) }
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appending(path: "\(name).png"))
    }
}

/// The commands the hosted timeline sent, in order.
@MainActor private final class KeyDragSent {
    var commands: [HaloCommand] = []
}

/// The Animation menu's key items, as HaloAnimationMenu builds them, drawn as buttons.
private struct AnimationKeyItems: View {
    let target: HaloMenuTarget

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Animation, on parented").font(SuiteFont.headline)
            target.item(.selectAllKeys)
            target.item(.moveKeys(by: -1, dragStart: 0), title: "Move Keyframes Left")
            target.item(.moveKeys(by: 1, dragStart: 0), title: "Move Keyframes Right")
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
