// HaloTransportFitTests.swift: the status bar's six transport controls
// (Start, Previous, Play/Pause, Next, End, Loop) each take at least a
// SuiteSize.pillHit square to click. As borderless icon-only buttons with
// 10 pt glyphs they were about 15 × 16 pt each (Anatomy round 3,
// halo-transport-playing-light.png); design.md wants hit targets of at
// least 28 pt and never under 20. Laid out unconstrained, the row must be
// at least pillHit tall and six pillHit squares wide, and no wider: the
// squares sit edge to edge (#1264) so the status bar still fits the content
// column with the timecode and layer count at the 1000 pt window.
// The journeys check each halo.transport.* frame in the live window.
// macOS only.
import AppKit
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloTransportFitTests {
    private static let controls: CGFloat = 6

    /// The size the transport row asks for, laid out as the status bar does.
    private func size(_ project: HaloProject) -> CGSize {
        let row = HaloTransport(model: project).controlSize(SuiteSize.compactControl)
        return NSHostingController(rootView: row).sizeThatFits(in: CGSize(width: 2000, height: 2000))
    }

    private func project() throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
        project.scrub(to: 12)
        return project
    }

    @Test func eachControlTakesAPillHitSquare() throws {
        let taken = size(try project())
        let squares = Self.controls * SuiteSize.pillHit
        #expect(taken.height >= SuiteSize.pillHit - 0.5, "the transport row is \(taken.height) pt tall")
        #expect(taken.width >= squares - 0.5, "the transport row is \(taken.width) pt wide, under \(squares)")
        #expect(taken.width <= squares + 0.5, "the transport row is \(taken.width) pt wide, over \(squares): gaps crept back")
    }

    @Test func playingKeepsThePillHitSquares() throws {
        var project = try project()
        project.play(at: 0)
        let taken = size(project)
        #expect(taken.height >= SuiteSize.pillHit - 0.5, "the playing transport row is \(taken.height) pt tall")
        #expect(taken.width >= Self.controls * SuiteSize.pillHit - 0.5, "the playing transport row is \(taken.width) pt wide")
    }
}
