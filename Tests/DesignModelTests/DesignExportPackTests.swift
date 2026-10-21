// DesignExportPackTests.swift: export-pack (Design). DesignExportOptionsSizeTests (DX-1): the
// options hold a SuiteExportSize, `.scale(1)` by default, the old `scale:` init is `.scale` of it, and
// JPEG is listed and plans as a ".jpg". DesignExportPackTests (MJ-DX, the Model walk; DX-3): a
// 540 × 675 pt frame at Pixels 1080 × 1350 plans exactly that (.exactPixels), Long edge 512 plans
// 410 × 512, SVG refuses Pixels with its reason, JPEG flattens onto the frame's fill (white with no
// frame) while PNG keeps alpha (.jpegFlattens), and RJ-D41's plan half (Tests/RealJobs/design/
// exact-jpeg) passes. Runs on Linux and macOS.
import Foundation
import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignExportOptionsSizeTests {
    @Test func theSizeDefaultsToOneX() {
        let options = DesignExportOptions()
        #expect(options.size == .scale(1))
        #expect(options.scale == 1)
        #expect(DesignWorkspace().exportDefaults.size == .scale(1))
    }

    @Test func theOldScaleInitIsAScaleSize() {
        let old = DesignExportOptions(format: .png, scale: 2, scope: .page)
        #expect(old.size == .scale(2))
        #expect(old == DesignExportOptions(format: .png, size: .scale(2), scope: .page))
        var pixels = DesignExportOptions(size: .pixels(width: 1080, height: 1350))
        #expect(pixels.scale == 1)
        pixels.scale = 3
        #expect(pixels.size == .scale(3))
    }

    @Test func jpegIsListedAndPlansAJPG() throws {
        #expect(DesignExportFormat.allCases == [.png, .jpeg, .svg, .pdf])
        #expect(DesignExportFormat.jpeg.fileExtension == "jpg" && DesignExportFormat.png.fileExtension == "png")
        let cards = DesignFixtures.cards
        for scope in [DesignExportScope.frame, .page] {
            let jpeg = DesignExportOptions(format: .jpeg, scale: 2, scope: scope)
            #expect(cards.exportHelp(jpeg) == nil)
            let plan = try cards.exportPlan(jpeg, existing: [])
            #expect(!plan.isEmpty && plan.allSatisfy { $0.fileName.hasSuffix(".jpg") && $0.pixelWidth == 2880 })
        }
        #expect(DesignExportOptions(format: .jpeg).scaleHelp == nil)
    }
}

extension Tag {
    @Tag static var exactPixels: Self
    @Tag static var jpegFlattens: Self
}

@Suite struct DesignExportPackTests {
    /// `cards` plus a selected 540 × 675 pt top-level frame, the packet's "Post".
    private func post() throws -> DesignWorkspace {
        var workspace = DesignFixtures.cards
        _ = try workspace.addNode(.frame, frame: rc(1500, 0, 540, 675), in: nil)
        return workspace
    }

    @Test(.tags(.exactPixels)) func pixelsPlanExactly() throws {
        let plan = try post().exportPlan(DesignExportOptions(format: .jpeg, size: .pixels(width: 1080, height: 1350)), existing: [])
        #expect(plan.map(\.pixelWidth) == [1080] && plan.map(\.pixelHeight) == [1350])
        #expect(plan.map(\.width) == [540] && plan.map(\.height) == [675])
        #expect(plan.allSatisfy { $0.fileName.hasSuffix(".jpg") })
        let page = try post().exportPlan(DesignExportOptions(format: .png, size: .pixels(width: 720, height: 512), scope: .page), existing: [])
        #expect(page.map(\.pixelWidth) == [720] && page.map(\.pixelHeight) == [512])
    }

    @Test(.tags(.exactPixels)) func aMisshapenPixelsSizeIsRefusedWithItsReason() throws {
        let workspace = try post()
        let squashed = DesignExportOptions(format: .jpeg, size: .pixels(width: 1080, height: 1080))
        let help = try #require(workspace.exportHelp(squashed))
        #expect(help.contains("1080"))
        #expect(throws: DesignRefusal.cantExport(help)) { try workspace.exportPlan(squashed, existing: []) }
        let stretched = DesignExportOptions(format: .jpeg, size: .pixels(width: 1080, height: 1080, stretch: true))
        #expect(try workspace.exportPlan(stretched, existing: []).map(\.pixelHeight) == [1080])
    }

    @Test func longEdgePlansInProportion() throws {
        let plan = try post().exportPlan(DesignExportOptions(format: .png, size: .longEdge(512)), existing: [])
        #expect(plan.map(\.pixelWidth) == [410] && plan.map(\.pixelHeight) == [512])
        let wide = try DesignFixtures.cards.exportPlan(DesignExportOptions(format: .jpeg, size: .longEdge(720)), existing: [])
        #expect(wide.map(\.pixelWidth) == [720] && wide.map(\.pixelHeight) == [512])
    }

    @Test(.tags(.exactPixels)) func scaleStaysClampedAndIsNotAppliedOnTopOfPixels() throws {
        let scaled = try post().exportPlan(DesignExportOptions(format: .jpeg, scale: 9), existing: [])
        #expect(scaled.map(\.pixelWidth) == [1620] && scaled.map(\.pixelHeight) == [2025])
        var options = DesignExportOptions(format: .png, scale: 3)
        options.size = .pixels(width: 1080, height: 1350)
        #expect(try post().exportPlan(options, existing: []).map(\.pixelWidth) == [1080])
    }

    @Test func svgRefusesPixels() throws {
        let workspace = try post()
        let svg = DesignExportOptions(format: .svg, size: .pixels(width: 1080, height: 1350))
        let reason = "SVG and PDF are vectors, so they export at their size in points. Choose a scale."
        #expect(workspace.exportHelp(svg) == reason)
        #expect(workspace.exportHelp(DesignExportOptions(format: .pdf, size: .longEdge(512))) == reason)
        #expect(throws: DesignRefusal.cantExport(reason)) { try workspace.exportPlan(svg, existing: []) }
        #expect(workspace.exportRows(svg).isEmpty)
        #expect(try workspace.exportPlan(DesignExportOptions(format: .svg, scale: 3), existing: []).map(\.pixelWidth) == [540])
    }

    @Test(.tags(.jpegFlattens)) func jpegFlattensOntoTheFramesFill() throws {
        var workspace = try post()
        let frame = try #require(workspace.selectedNodeID)
        let teal = DesignColor(0, 128, 128)
        try workspace.setFill(frame, teal)
        let child = try workspace.addNode(.rectangle, frame: rc(1600, 100, 50, 50), in: frame)
        workspace.selectItem(child)
        for scope in [DesignExportScope.frame, .selection] {
            let jpeg = try workspace.exportPlan(DesignExportOptions(format: .jpeg, scope: scope), existing: [])
            #expect(jpeg.map(\.background) == [teal], "\(scope)")
            let png = try workspace.exportPlan(DesignExportOptions(format: .png, scope: scope), existing: [])
            #expect(png.map(\.background) == [nil], "\(scope)")
        }
        _ = try workspace.addNode(.ellipse, frame: rc(2200, 0, 40, 40), in: nil)
        #expect(try workspace.exportPlan(DesignExportOptions(format: .jpeg, scope: .selection), existing: []).map(\.background) == [.white])
        #expect(try workspace.exportPlan(DesignExportOptions(format: .jpeg, scope: .page), existing: []).map(\.background) == [.white])
        #expect(try workspace.exportPlan(DesignExportOptions(format: .svg, scope: .page), existing: []).map(\.background) == [nil])
    }

    /// RJ-D41's plan half: the job's own options, read as the run reads them, plan the job's files.
    @Test(.tags(.exactPixels, .jpegFlattens)) func theRealJobsPlanHalf() throws {
        struct Job: Decodable { var output: Output }
        struct Output: Decodable { var format: String; var options: JSONValue }
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RealJobs/design/exact-jpeg")
        let job = try JSONDecoder().decode(Job.self, from: Data(contentsOf: folder.appendingPathComponent("exact-jpeg.jobs.json")))
        let options = try SuiteExportOptions(json: job.output.options, defaults: SuiteExportOptions(format: job.output.format))
        let data = try Data(contentsOf: folder.appendingPathComponent("input/cards.design"))
        let workspace = try DesignHeadless.open(data, name: "cards.design").workspace
        let format = try #require(DesignExportFormat(rawValue: job.output.format))
        let jpeg = try workspace.exportPlan(DesignExportOptions(format: format, size: options.size), existing: [])
        #expect(jpeg.map(\.fileName) == ["Post.jpg"])
        #expect(jpeg.map(\.pixelWidth) == [1080] && jpeg.map(\.pixelHeight) == [1350])
        #expect(jpeg.map(\.background) == [.white])
        let png = try workspace.exportPlan(DesignExportOptions(format: .png, size: .longEdge(512)), existing: [])
        #expect(png.map(\.pixelWidth) == [410] && png.map(\.pixelHeight) == [512] && png.map(\.background) == [nil])
    }
}
