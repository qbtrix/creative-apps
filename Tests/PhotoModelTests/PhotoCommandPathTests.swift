// PhotoCommandPathTests.swift (command-state CS-9): the catalog command each of Photo's bare controls runs once
// CS-10 wires it. Every id is in the catalog and the ledger with a params schema and runs headless; each sheet's
// confirm runs its command with the sheet's values (Export's format and quality, Image Size's sides, Straighten's
// angle and Crop to Fit), and Open Recent and Clear Menu run the shared file-flow commands. Each says why it is off.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import Testing
@testable import PhotoModel

struct PhotoCommandPathTests {
    /// A control, the id it must run and the params its confirm sends (the sheet's values).
    struct Control: Sendable, CustomStringConvertible {
        let name, id: String
        let params: JSONValue
        var description: String { name }
    }

    static let recentPath = FileManager.default.temporaryDirectory.appendingPathComponent("photo-cs9-recent.png").path
    static let recentID = "path:" + recentPath

    static let controls = [
        Control(name: "ExportSheet Export", id: "file.export",
                params: .object(["format": .string("jpeg"), "quality": .number(0.5)])),
        Control(name: "ImageSizeSheet Resize", id: "image.resize", params: .object(["width": .number(8), "height": .number(6)])),
        Control(name: "StraightenSheet Apply", id: "image.straighten",
                params: .object(["degrees": .number(3), "cropToFit": .bool(true)])),
        Control(name: "Open Recent item", id: "file.open-recent", params: .object(["fileID": .string(recentID)])),
        Control(name: "Open Recent Clear Menu", id: "file.clear-recent", params: .object([:])),
        Control(name: "PhotoWindow Rename", id: "layer.rename", params: .object(["name": .string("Sky")])),
    ]

    /// A 16 × 12 image with one recent file on disk, its Export sheet open.
    static func fixture() throws -> PhotoWorkspace {
        var ws = PhotoWorkspace(services: .fake)
        try ws.newCanvas(width: 16, height: 12)
        try Data([1]).write(to: URL(fileURLWithPath: recentPath))
        let entry = RecentFileEntry(fileID: recentID, name: "photo-cs9-recent.png", path: recentPath, app: "photo",
                                    lastUsed: Date(timeIntervalSince1970: 0))
        ws.updateFileFlow(recents: [entry], documentPath: nil)
        ws.openExport()
        return ws
    }

    @Test(arguments: controls) func idIsCataloguedAndLedgered(_ control: Control) throws {
        let spec = try #require(PhotoWorkspace.catalog.spec(control.id), "\(control.id) is in Photo's catalog")
        #expect(spec.params.validate(control.params).isEmpty, "the confirm's params fit \(control.id)'s schema")
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/photo.txt")
        let ledger = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(ledger.contains(control.id), "\(control.id) is in the ledger")
    }

    @Test(arguments: controls) func runsHeadless(_ control: Control) throws {
        var ws = try Self.fixture()
        #expect(throws: Never.self) { _ = try PhotoWorkspace.catalog.run(control.id, params: control.params, on: &ws) }
    }

    /// Each sheet's confirm runs with the sheet's values, and they reach the run.
    @Test func paramsReachRun() throws {
        var ws = try Self.fixture()
        let exported = try PhotoWorkspace.catalog.run("file.export", params: Self.controls[0].params, on: &ws).result
        #expect(ws.exportOptions.format == .jpeg && ws.exportOptions.quality == 0.5, "Export keeps the sheet's choice")
        #expect(ws.isExportRunning, "Export from the open sheet starts its write")
        guard case .object(let out) = exported else { Issue.record("Export returns an object"); return }
        #expect(out["quality"] == .number(0.5) && out["name"] == .string(ws.fileName(for: .jpeg)))

        let turned = try #require(ws.straightenFrame(degrees: 3, cropToFit: true)).size
        let grown = try #require(ws.straightenFrame(degrees: 3, cropToFit: false)).size
        #expect(turned != grown)
        var cropped = ws
        _ = try PhotoWorkspace.catalog.run("image.straighten", params: Self.controls[2].params, on: &cropped)
        #expect(cropped.canvas == turned)
        _ = try PhotoWorkspace.catalog.run("image.straighten",
                                           params: .object(["degrees": .number(3), "cropToFit": .bool(false)]), on: &ws)
        #expect(ws.canvas == grown)

        _ = try PhotoWorkspace.catalog.run("image.resize", params: Self.controls[1].params, on: &ws)
        #expect(ws.canvas == CanvasSize(width: 8, height: 6))

        _ = try PhotoWorkspace.catalog.run("file.open-recent", params: Self.controls[3].params, on: &ws)
        #expect(ws.takeFileRequests() == [.open(path: Self.recentPath)])
        _ = try PhotoWorkspace.catalog.run("file.clear-recent", params: .object([:]), on: &ws)
        #expect(ws.recentFiles.isEmpty)
    }

    /// Without an image the sheets' commands say so; with no recent files Clear Menu says so.
    @Test func reasonWhenUnavailable() throws {
        let none = PhotoWorkspace(services: .fake)
        for id in ["image.resize", "image.straighten", "layer.rename"] {
            #expect(PhotoWorkspace.catalog.availability(id, on: none).why == "Open an image first.", "\(id)")
        }
        // Export shares the toolbar's Export button reason.
        #expect(PhotoWorkspace.catalog.availability("file.export", on: none).why == "Open or create an image first.")
        #expect(PhotoWorkspace.catalog.availability("file.clear-recent", on: none).why == "No Recent Files")
        let ws = try Self.fixture()
        for control in Self.controls {
            #expect(PhotoWorkspace.catalog.availability(control.id, on: ws).why == nil, "\(control.id) runs on an open image")
        }
    }
}
