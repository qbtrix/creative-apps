// HaloProResTests.swift: MJ-HX (export-pack HX-1, HX-3, HX-4). The render
// settings' codec and Transparent background flag on the `keyed` fixture
// ("Bounce", 1920 × 1080, 24 fps, 48 frames) with the fake services. HX-1's
// tests: the defaults, the checkbox's refusal in ExportRules' words, and every
// plan as it was. HX-3's: the plan refuses alpha on H.264 and names a ProRes
// movie .mov. HX-4's: every codec the row offers can be picked, and HEVC with
// alpha, which it doesn't offer, can't. Linux and macOS.
import HaloModel
import SuiteModel
import Testing

@Suite struct HaloProResTests {
    private static let movie = HaloRenderSettings(format: .movie)

    private static func keyed() throws -> HaloProject {
        HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
    }

    @Test func settingsDefaultToH264WithoutAlpha() {
        let settings = HaloRenderSettings(format: .pngSequence, halfSize: true)
        #expect(settings.codec == .h264)
        #expect(!settings.alpha)
        #expect(Self.movie == HaloRenderSettings(format: .movie, halfSize: false, codec: .h264, alpha: false))
    }

    @Test func codecRowOffersH264HevcAndProRes() {
        #expect(HaloRenderSettings.codecs == [.h264, .hevc, .prores4444])
        #expect(HaloRenderSettings.codecs.map(HaloRenderSettings.codecTitle) == ["H.264", "HEVC", "ProRes 4444"])
    }

    @Test func everyOfferedCodecCanBePicked() {
        for codec in HaloRenderSettings.codecs {
            #expect(HaloRenderSettings.codecRefusal(codec) == nil, "\(codec) is refused")
            #expect(Self.movie.choosing(codec: codec).codec == codec)
        }
        #expect(HaloRenderSettings.codecRefusal(.hevcAlpha) == HaloRenderSettings.hevcAlphaRefused)
        #expect(Self.movie.choosing(codec: .hevcAlpha) == Self.movie)
    }

    /// A refusal is a tooltip a person reads, so it never names a build slice ("HX-4").
    @Test func codecRefusalsNeverNameASlice() {
        for codec in HaloRenderSettings.codecs + [.hevcAlpha] {
            #expect(!(HaloRenderSettings.codecRefusal(codec) ?? "").contains("HX-"))
        }
    }

    @Test func h264RefusesTransparencyInExportRulesWords() {
        #expect(Self.movie.alphaRefusal == "H.264 can't keep transparency. Choose ProRes 4444.")
        #expect(Self.movie.choosing(alpha: true) == Self.movie)
        #expect(Self.movie.choosing(alpha: false) == Self.movie)
    }

    @Test func pngSequenceMayAlwaysKeepTransparency() {
        let png = HaloRenderSettings(format: .pngSequence)
        #expect(png.alphaRefusal == nil)
        #expect(png.choosing(alpha: true).alpha)
        // Moving to an H.264 movie turns it off, since the movie can't keep it.
        let moved = png.choosing(alpha: true).choosing(format: .movie)
        #expect(moved.format == .movie && !moved.alpha)
        #expect(moved.choosing(format: .pngSequence).choosing(halfSize: true) == HaloRenderSettings(format: .pngSequence, halfSize: true))
    }

    @Test func theNewFieldsLeaveEveryPlanAsItWas() throws {
        let project = try Self.keyed()
        let comp = try #require(project.selectedComposition)
        let rendering = project.services.compositionRendering
        for format in HaloRenderSettings.Format.allCases {
            for half in [false, true] {
                let plain = HaloRenderSettings(format: format, halfSize: half)
                let flagged = HaloRenderSettings(format: format, halfSize: half, codec: .h264, alpha: format == .pngSequence)
                #expect(try rendering.plan(comp, settings: flagged) == rendering.plan(comp, settings: plain))
            }
        }
        #expect(project.renderSummary(Self.movie, existing: []) == "One movie, 1920 × 1080, 24 fps, \"Bounce.mp4\"")
    }

    @Test func theSheetKeepsCodecAndAlphaAcrossEdits() throws {
        var project = try Self.keyed()
        let png = HaloRenderSettings(format: .pngSequence).choosing(alpha: true)
        let began = project.beginRender(png)
        #expect(began)
        project.setRenderSettings(png.choosing(halfSize: true))
        #expect(project.renderRun == .editing(HaloRenderSettings(format: .pngSequence, halfSize: true, alpha: true)))
    }

    // HX-3: the plan's codec and alpha rules; HX-4: picking ProRes.

    @Test func proResCanBePickedAndKeepsAlpha() {
        let prores = Self.movie.choosing(codec: .prores4444)
        #expect(prores.codec == .prores4444)
        #expect(prores.alphaRefusal == nil)
        #expect(prores.choosing(alpha: true).alpha)
        #expect(prores.choosing(alpha: true).choosing(codec: .h264).alpha == false)
    }

    @Test func thePlanRefusesAlphaOnH264InItsSentence() throws {
        var project = try Self.keyed()
        let comp = try #require(project.selectedComposition)
        let refused = HaloRenderSettings(format: .movie, alpha: true)
        #expect(throws: (any Error).self) { try project.services.compositionRendering.plan(comp, settings: refused) }
        let began = project.beginRender(refused), started = project.startRender()
        #expect(began && started == nil)
        guard case .failed(_, let message) = project.renderRun else {
            Issue.record("the run did not fail: \(project.renderRun)")
            return
        }
        #expect(message.contains("H.264 can't keep transparency. Choose ProRes 4444."))
    }

    @Test func proResWithAlphaPlansAMovFile() throws {
        let project = try Self.keyed()
        let comp = try #require(project.selectedComposition)
        let settings = HaloRenderSettings(format: .movie, codec: .prores4444, alpha: true)
        let plan = try project.services.compositionRendering.plan(comp, settings: settings)
        #expect(plan.fileNames == ["Bounce.mov"])
        #expect(project.renderOutputName(settings, existing: []) == "Bounce.mov")
    }
}
