// DesignExportPackTests.swift: export-pack (Design). DesignExportOptionsSizeTests (DX-1, on): the
// options hold a SuiteExportSize, `.scale(1)` by default, the old `scale:` init is `.scale` of it, and
// JPEG is listed and refused with its reason until DX-3. DesignExportPackTests (MJ-DX, the Model walk;
// written by DX-1, off until DX-3 builds the plan's exact pixels): a 540 × 675 pt frame at Pixels
// 1080 × 1350 plans exactly that, Long edge 512 plans 410 × 512, and SVG refuses Pixels with its
// reason. Runs on Linux and macOS.
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

    @Test func jpegIsListedAndRefusedWithItsReason() {
        #expect(DesignExportFormat.allCases == [.png, .jpeg, .svg, .pdf])
        let cards = DesignFixtures.cards
        for scope in DesignExportScope.allCases {
            let jpeg = DesignExportOptions(format: .jpeg, scope: scope)
            #expect(cards.exportHelp(jpeg) == "JPEG lands with DX-3.")
            #expect(throws: DesignRefusal.notYet("JPEG lands with DX-3.")) { try cards.exportPlan(jpeg, existing: []) }
            #expect(cards.exportRows(jpeg).isEmpty)
        }
        let page = cards.selectedPage ?? DesignPage(id: "none", name: "None", frameWidth: 1, frameHeight: 1)
        #expect(throws: DesignRefusal.notYet("JPEG lands with DX-3.")) {
            try LiveExport().plan([], on: page, format: .jpeg, scale: 1, existing: [])
        }
        #expect(cards.exportHelp(DesignExportOptions(format: .png)) == nil)
    }
}

@Suite(.disabled("DX-3 builds the plan's exact pixel sizes"))
struct DesignExportPackTests {
    /// `cards` plus a selected 540 × 675 pt top-level frame, the packet's "Post".
    private func post() throws -> DesignWorkspace {
        var workspace = DesignFixtures.cards
        _ = try workspace.addNode(.frame, frame: rc(1500, 0, 540, 675), in: nil)
        return workspace
    }

    @Test func pixelsPlanExactly() throws {
        let plan = try post().exportPlan(DesignExportOptions(format: .jpeg, size: .pixels(width: 1080, height: 1350)), existing: [])
        #expect(plan.map(\.pixelWidth) == [1080] && plan.map(\.pixelHeight) == [1350])
        #expect(plan.allSatisfy { $0.fileName.hasSuffix(".jpg") })
    }

    @Test func longEdgePlansInProportion() throws {
        let plan = try post().exportPlan(DesignExportOptions(format: .png, size: .longEdge(512)), existing: [])
        #expect(plan.map(\.pixelWidth) == [410] && plan.map(\.pixelHeight) == [512])
    }

    @Test func svgRefusesPixels() throws {
        let workspace = try post()
        let svg = DesignExportOptions(format: .svg, size: .pixels(width: 1080, height: 1350))
        #expect(workspace.exportHelp(svg) != nil)
        #expect(workspace.exportRows(svg).isEmpty)
    }
}
