// HaloCommandPathTests.swift (command-state CS-7): the catalog command each of Halo's bare controls runs once
// CS-8 wires it. Every id is in the catalog and the ledger with a params schema and runs headless; each sheet's
// confirm runs its command with the sheet's values (New Composition's settings, the render sheet's format and size),
// the unsaved alert's Save and Don't Save run one command with the kernel's answer, and each says why it is off.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import HaloModel
import SuiteKernel
import Testing

struct HaloCommandPathTests {
    /// A control, the id it must run and the params its confirm sends (the sheet's values).
    struct Control: Sendable, CustomStringConvertible {
        let name, id: String
        let params: JSONValue
        var description: String { name }
    }

    static let none: JSONValue = .object([:])
    static let newSettings: JSONValue = .object(["name": .string("Titles"), "width": .number(640), "height": .number(360),
                                                 "fps": .number(24), "seconds": .number(2)])
    static let renderSettings: JSONValue = .object(["format": .string("movie"), "halfSize": .bool(true)])

    static let controls = [
        Control(name: "HaloTransport Go to Start", id: "animation.go-to-start", params: none),
        Control(name: "HaloTransport Previous Frame", id: "animation.previous-frame", params: none),
        Control(name: "HaloTransport Play/Pause", id: "animation.play-pause", params: none),
        Control(name: "HaloTransport Next Frame", id: "animation.next-frame", params: none),
        Control(name: "HaloTransport Go to End", id: "animation.go-to-end", params: none),
        Control(name: "HaloTransport Loop", id: "animation.loop", params: none),
        Control(name: "Layers Rename", id: "layer.rename", params: .object(["id": .string("comp-1-layer-1"), "name": .string("Ground")])),
        Control(name: "RenameRefusalAlert Rename", id: "composition.rename", params: .object(["id": .string("comp-1"), "name": .string("Intro")])),
        Control(name: "NewCompositionSheet Create", id: "composition.new", params: newSettings),
        Control(name: "Render sheet Choose…", id: "render.choose-folder", params: none),
        Control(name: "Render sheet Render", id: "render.start", params: renderSettings),
        Control(name: "Unsaved alert Save", id: "file.answer-unsaved", params: .object(["answer": .string("save")])),
        Control(name: "Unsaved alert Don't Save", id: "file.answer-unsaved", params: .object(["answer": .string("dontSave")])),
    ]

    /// `keyed` with an unsaved edit, the playhead mid-way and the render sheet open.
    static func fixture() -> HaloProject {
        var project = commandProject("keyed", .fake)
        project.newLayer(.solid)
        project.scrub(to: 12)
        project.beginRender(HaloRenderSettings(format: .pngSequence))
        return project
    }

    @Test(arguments: controls) func idIsCataloguedAndLedgered(_ control: Control) throws {
        let spec = try #require(HaloProject.catalog.spec(control.id), "\(control.id) is in Halo's catalog")
        #expect(spec.params.validate(control.params).isEmpty, "the confirm's params fit \(control.id)'s schema")
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/halo.txt")
        let ledger = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(ledger.contains(control.id), "\(control.id) is in the ledger")
    }

    @Test(arguments: controls) func runsHeadless(_ control: Control) throws {
        var project = Self.fixture()
        #expect(throws: Never.self) { _ = try HaloProject.catalog.run(control.id, params: control.params, on: &project) }
    }

    /// Each sheet's confirm runs with the sheet's values, and they reach the run.
    @Test func paramsReachRun() throws {
        var project = Self.fixture()
        _ = try HaloProject.catalog.run("composition.new", params: Self.newSettings, on: &project)
        let made = try #require(project.selectedComposition)
        #expect(made.name == "Titles" && made.width == 640 && made.height == 360)
        #expect(made.framesPerSecond == 24 && made.durationFrames == 48)

        var refused = Self.fixture()
        let before = refused.compositions
        #expect(throws: CatalogError.self) {
            try HaloProject.catalog.run("composition.new", params: .object(["width": .number(0)]), on: &refused)
        }
        #expect(refused.compositions == before, "a refused sheet adds nothing")

        var rendering = Self.fixture()
        _ = try HaloProject.catalog.run("render.start", params: Self.renderSettings, on: &rendering)
        #expect(rendering.renderJob?.settings == HaloRenderSettings(format: .movie, halfSize: true), "the sheet's choice renders")
        #expect(rendering.renderRunning, "Render from the open sheet starts the run")

        var asked = Self.fixture()
        let answered = try HaloProject.catalog.run("file.answer-unsaved", params: Self.controls[12].params, on: &asked)
        #expect(answered.result == .object(["answer": .string("dontSave")]), "the window reads the answer")
    }

    /// With no render open the sheet's commands say so; with nothing unsaved the alert's answers say so.
    @Test func reasonWhenUnavailable() {
        let closed = commandProject("keyed", .fake)
        for id in ["render.choose-folder", "render.start"] {
            #expect(HaloProject.catalog.availability(id, on: closed).why == "No render is open.", "\(id)")
        }
        #expect(HaloProject.catalog.availability("file.answer-unsaved", on: closed).why == "There are no unsaved changes.")
        let project = Self.fixture()
        for control in Self.controls {
            #expect(HaloProject.catalog.availability(control.id, on: project).why == nil, "\(control.id) runs on the open sheet")
        }
    }
}
