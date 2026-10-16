// FlareIntentTests.swift: DK-2a of draw-key-save (#347). Every FlareIntent case has one stable identifier,
// "flare.<area>.<case name>": unique, independent of its payload, and naming the area its case belongs to.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import FlareModel
import Testing

struct FlareIntentTests {
    @Test func identifiersAreUniqueAndWellFormed() throws {
        let ids = FlareIntent.examples.map(\.identifier)
        #expect(Set(ids).count == ids.count)
        let pattern = try Regex("^flare\\.[a-z]+\\.[a-zA-Z0-9]+$")
        for id in ids {
            #expect(id.wholeMatch(of: pattern) != nil, "\(id)")
        }
    }

    @Test func examplesListEveryCase() {
        // The contract slice's case count: 9 file, 11 edit, 3 stage, 2 tools, 13 view, 16 inspector,
        // 18 timeline, 8 layers, 9 library, 1 interactions, 1 export, 1 assist.
        #expect(FlareIntent.examples.count == 92)
    }

    @Test func aPayloadDoesNotChangeTheIdentifier() {
        #expect(FlareIntent.timeline(.scrub(frame: 3)).identifier == FlareIntent.timeline(.scrub(frame: 9)).identifier)
        #expect(FlareIntent.timeline(.scrub(frame: 3)).identifier == "flare.timeline.scrub")
        #expect(FlareIntent.tools(.choose(.pen)).identifier == FlareIntent.tools(.choose(.ellipse)).identifier)
        #expect(FlareIntent.layers(.rename(id: "a", name: "x")).identifier
            == FlareIntent.layers(.rename(id: "b", name: "y")).identifier)
        #expect(FlareIntent.stage(.dragChanged(start: Point(x: 0, y: 0), end: Point(x: 1, y: 2), shift: true,
                                               option: false, stageScale: 2)).identifier == "flare.stage.dragChanged")
    }

    @Test func everyAreaHasACase() {
        let areas = Set(FlareIntent.examples.map(\.area))
        for area in FlareIntent.Area.allCases {
            #expect(areas.contains(area), "\(area)")
        }
    }

    @Test func areaAgreesWithTheCase() {
        #expect(FlareIntent.file(.save).area == .file)
        #expect(FlareIntent.edit(.undo).area == .edit)
        #expect(FlareIntent.stage(.endDrag).area == .stage)
        #expect(FlareIntent.tools(.finishPath).area == .tools)
        #expect(FlareIntent.view(.fit).area == .view)
        #expect(FlareIntent.inspector(.endScrub).area == .inspector)
        #expect(FlareIntent.timeline(.togglePlay).area == .timeline)
        #expect(FlareIntent.layers(.addLayer).area == .layers)
        #expect(FlareIntent.library(.addSwatch).area == .library)
        #expect(FlareIntent.interactions(.toggleEditor).area == .interactions)
        #expect(FlareIntent.export(.showSheet).area == .export)
        #expect(FlareIntent.assist(.showPopover).area == .assist)
        for intent in FlareIntent.examples {
            #expect(intent.identifier.hasPrefix("flare.\(intent.area.rawValue)."), "\(intent.identifier)")
        }
    }

    @Test func spotIdentifiers() {
        #expect(FlareIntent.edit(.selectAll).identifier == "flare.edit.selectAll")
        #expect(FlareIntent.file(.openRecent(path: "/a")).identifier == "flare.file.openRecent")
        #expect(FlareIntent.library(.edit(id: "s")).identifier == "flare.library.edit")
        #expect(FlareIntent.view(.removeGuide(index: 0)).identifier == "flare.view.removeGuide")
        #expect(FlareIntent.inspector(.easingHandle(index: 1, x: 0.2, y: 0.4)).identifier
            == "flare.inspector.easingHandle")
    }
}
