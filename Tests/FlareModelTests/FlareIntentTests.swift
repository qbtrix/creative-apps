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
        // A name is one word, or two for the export format chips ("format.lottie").
        let pattern = try Regex("^flare\\.[a-z]+\\.[a-zA-Z0-9]+(\\.[a-zA-Z0-9]+)?$")
        for id in ids {
            #expect(id.wholeMatch(of: pattern) != nil, "\(id)")
        }
    }

    @Test func examplesListEveryCase() {
        // The contract slices' case count: 9 file, 11 edit, 3 stage, 2 tools, 13 view, 16 inspector,
        // 18 timeline, 8 layers, 9 library, 1 interactions, 11 export (flare-export FX-1), 1 assist.
        #expect(FlareIntent.examples.count == 102)
    }

    @Test func exportFormatChipsRegisterApart() {
        // flare-export FX-1: the three format chips are three controls, "flare.export.format.<rawValue>".
        let ids = ExportFormat.allCases.map { FlareIntent.export(.setFormat($0)).identifier }
        #expect(Set(ids).count == ExportFormat.allCases.count)
        for (format, id) in zip(ExportFormat.allCases, ids) {
            #expect(id.hasSuffix(".format.\(format.rawValue)"), "\(id)")
            #expect(id.hasPrefix("flare.export."), "\(id)")
        }
        #expect(FlareIntent.export(.setFormat(.lottie)).identifier == "flare.export.format.lottie")
        #expect(FlareIntent.export(.setFormat(.svgFrame)).identifier == "flare.export.format.svgFrame")
        #expect(FlareIntent.export(.setFormat(.pngSequence)).identifier == "flare.export.format.pngSequence")
    }

    static let exportCases: [FlareIntent.Export] = [
        .showSheet, .setFormat(.svgFrame), .setFrames(from: 0, to: 47), .setStep(1), .setScale(2),
        .setTransparent(true), .start, .cancel, .dismiss, .tryAgain, .reveal,
    ]

    @Test func everyExportCaseKeepsItsArea() {
        #expect(Self.exportCases.count == 11)
        for intent in Self.exportCases {
            let whole = FlareIntent.export(intent)
            #expect(whole.area == .export, "\(whole.identifier)")
            #expect(whole.identifier.hasPrefix("flare.export."), "\(whole.identifier)")
        }
        #expect(FlareIntent.export(.start).identifier == "flare.export.start")
        #expect(FlareIntent.export(.setFrames(from: 0, to: 9)).identifier == "flare.export.setFrames")
        #expect(FlareIntent.export(.reveal).identifier == "flare.export.reveal")
        #expect(FlareIntent.export(.tryAgain).identifier == "flare.export.tryAgain")
    }

    @Test func everyExportCaseHasATitle() {
        let titles = Self.exportCases.map { FlareIntent.export($0).title }
        #expect(!titles.contains(""))
        #expect(Set(titles).count == titles.count)
        #expect(FlareIntent.export(.showSheet).title == "Export…")
        #expect(FlareIntent.export(.start).title == "Export")
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

    @Test func eachPaletteToolHasItsOwnControlIdentifier() {
        let ids = FlareTool.allCases.map { FlareIntent.tools(.choose($0)).controlIdentifier }
        #expect(Set(ids).count == FlareTool.allCases.count)
        #expect(FlareIntent.tools(.choose(.pen)).controlIdentifier == "flare.tools.choose.pen")
        #expect(FlareIntent.timeline(.scrub(frame: 3)).controlIdentifier == "flare.timeline.scrub")
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
