// HaloViewerNoticeTests.swift: the first-use text around Halo's viewer. The
// artboard's caption says why it is blank only while there are layers a
// frame drawer that can't draw would leave out (the live drawer draws), and the status bar's tooltips name
// what the timecode's four parts and the zoom and size pills mean. Runs on
// Linux and macOS.
@testable import HaloModel
import Testing

/// `name` loaded on `services`, first composition selected.
private func fixture(_ name: String, on services: HaloServices) throws -> HaloProject {
    var project = HaloProject(services: services)
    project.restore(try #require(HaloFixtures.project(name)))
    return project
}

struct HaloViewerNoticeTests {
    @Test func liveDrawingDrawsSoTheArtboardHasNoCaption() throws {
        #expect(HaloServices.live.drawing.unavailableHelp == nil)
        let project = try fixture("three-layers", on: .live)
        #expect(project.viewerNotice == nil)
    }

    @Test func noNoticeWithoutLayersOrWithoutAComposition() throws {
        #expect(try fixture("empty", on: .live).viewerNotice == nil)
        #expect(HaloProject(services: .live).viewerNotice == nil)
    }

    @Test func noNoticeWhenTheDrawerDraws() throws {
        #expect(HaloServices.fake.drawing.unavailableHelp == nil)
        #expect(try fixture("three-layers", on: .fake).viewerNotice == nil)
    }

    @Test func timecodeHelpNamesItsPartsAndThePlayheadFrame() throws {
        var project = HaloProject()
        project.newComposition()
        project.scrub(to: 45)
        let comp = try #require(project.selectedComposition)
        #expect(
            comp.statusTimecodeHelp
                == "Hours:minutes:seconds:frames, then the frame, at the playhead (frame 45 of 0–299). "
                + "The composition runs 10 s at 30 fps.")
        #expect(comp.statusTimecode == "00:00:01:15 · frame 45")
    }

    @Test func zoomAndSizePillsSayWhatTheyShow() {
        #expect(HaloComposition.viewerPillsHelp.contains("zoom"))
        #expect(HaloComposition.viewerPillsHelp.contains("pixels"))
    }
}
