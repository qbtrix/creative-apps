// HaloViewerSelectedDragTests.swift: H-J5 (#1283) in a hosted window. On
// `-HaloSample keyed` at the journey's 1000 x 640, with Ball selected (so its
// selection handles sit over the viewer) and the playhead at 12, a press at
// Ball's position and a drag 100 px right moves Ball's Position X from 560 to
// 660 and lands as one "Move". The same drag on Floor at 0 moves its static
// Y. The press is sent to the window as mouse events (HostedHaloWindow), never
// as real input. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct HaloViewerSelectedDragTests {
        static let ball = "comp-1-layer-2", floor = "comp-1-layer-1"

        @Test(.timeLimit(.minutes(3))) func aDragOnTheSelectedBallKeysItsPosition() async throws {
            var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            project.selectLayer(Self.ball)
            project.scrub(to: 12)
            let after = try await Self.drag(project, by: (100, 0))
            let x = after.propertyRows.first { $0.property == .x }?.value
            #expect(x.map { abs($0 - 660) < 2 } == true, "Ball's Position X after a 100 px drag: \(x.map { "\($0)" } ?? "nil")")
            #expect(after.undoTitle == "Undo Move", "undo reads \(after.undoTitle ?? "nil")")
            #expect(after.selectedLayerID == Self.ball)
        }

        @Test(.timeLimit(.minutes(3))) func aDragOnTheSelectedFloorMovesItsStaticY() async throws {
            var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            project.selectLayer(Self.floor)
            let y = try #require(project.propertyRows.first { $0.property == .y }?.value)
            let after = try await Self.drag(project, by: (0, 50))
            let moved = after.propertyRows.first { $0.property == .y }?.value
            #expect(moved.map { abs($0 - (y + 50)) < 2 } == true, "Floor's Position Y \(y) after a 50 px drag: \(moved.map { "\($0)" } ?? "nil")")
            #expect(after.undoTitle == "Undo Move", "undo reads \(after.undoTitle ?? "nil")")
        }

        /// Hosts `project` at 1000 x 640, presses at the selected layer's
        /// position (as H-J5 aims, from `halo.viewer.canvas`) and drags by
        /// `delta` composition pixels; the project the window shows after.
        static func drag(_ project: HaloProject, by delta: (Double, Double)) async throws -> HaloProject {
            let x = try #require(project.propertyRows.first { $0.property == .x }?.value)
            let y = try #require(project.propertyRows.first { $0.property == .y }?.value)
            let hosted = try await HostedHaloWindow(project, size: CGSize(width: 1000, height: 640))
            defer { hosted.close() }
            let canvas = try #require(hosted.frame(of: "halo.viewer.canvas"), "no halo.viewer.canvas")
            let comp = try #require(project.selectedComposition)
            let scale = canvas.width / CGFloat(comp.width)
            // Window points are y-up; composition pixels are y-down from the artboard's top left.
            let start = CGPoint(x: canvas.minX + CGFloat(x) * scale, y: canvas.maxY - CGFloat(y) * scale)
            let end = CGPoint(x: start.x + CGFloat(delta.0) * scale, y: start.y - CGFloat(delta.1) * scale)
            return try await hosted.drag(from: start, to: end).after
        }
    }
}
#endif
