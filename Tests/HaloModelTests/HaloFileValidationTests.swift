// HaloFileValidationTests.swift: LiveProjectFiles refuses a project whose
// contents break a rule the app keeps (HF-5, #209), naming the item, and
// raises the id counters past the highest id on open. Each test mutates
// the `two-comps` fixture (Intro: Title, Badge, Background, Rig; Outro:
// Ball, Floor) in one way. Runs on Linux and macOS.
import Foundation
@testable import HaloModel
import Testing

/// `two-comps` changed by `change`, written by the live type.
private func twoComps(_ change: (inout HaloDocumentState) -> Void) throws -> Data {
    var state = try #require(HaloFixtures.project("two-comps"))
    change(&state)
    return try LiveProjectFiles().encode(state)
}

/// The reason live decoding gives for `data`; nil when it opens or throws
/// something other than `.damaged`.
private func damagedReason(_ data: Data) -> String? {
    do {
        _ = try LiveProjectFiles().decode(data)
        return nil
    } catch HaloFileError.damaged(let reason) {
        return reason
    } catch {
        return nil
    }
}

/// The index of the layer named `name` in composition `comp`.
private func layerIndex(_ name: String, _ comp: Int, _ state: HaloDocumentState) -> Int {
    state.compositions[comp].layers.firstIndex { $0.name == name } ?? -1
}

@Test func twoCompositionsWithOneIdAreDamaged() throws {
    let data = try twoComps { state in
        let outro = state.compositions[1]
        state.compositions[1] = HaloComposition(
            id: "comp-1", name: outro.name, width: outro.width, height: outro.height,
            framesPerSecond: outro.framesPerSecond, durationFrames: outro.durationFrames, layers: outro.layers)
    }
    #expect(damagedReason(data) == "two compositions share the id comp-1")
}

@Test func lookAlikeNamesAreDamaged() throws {
    let data = try twoComps { $0.compositions[1].name = "intro" }
    let reason = try #require(damagedReason(data))
    #expect(reason.contains("Intro") && reason.contains("intro"))
}

@Test(arguments: [0, 8193])
func aWidthOutsideTheSizesIsDamaged(width: Int) throws {
    let data = try twoComps { $0.compositions[0].width = width }
    let reason = try #require(damagedReason(data))
    #expect(reason.contains("Intro") && reason.contains("\(width)"))
}

@Test func anUnknownFrameRateIsDamaged() throws {
    let data = try twoComps { $0.compositions[1].framesPerSecond = 23 }
    let reason = try #require(damagedReason(data))
    #expect(reason.contains("Outro") && reason.contains("23"))
}

@Test(arguments: [0, 86_400 * 24 + 1])
func aDurationOutsideTheLimitIsDamaged(frames: Int) throws {
    let data = try twoComps { $0.compositions[0].durationFrames = frames }
    let reason = try #require(damagedReason(data))
    #expect(reason.contains("Intro") && reason.contains("\(frames)"))
}

@Test func twoLayersWithOneIdAreDamaged() throws {
    let data = try twoComps { state in
        let ball = state.compositions[1].layers[0]
        state.compositions[1].layers[1] = HaloLayer(
            id: ball.id, name: "Floor", kind: .solid, inFrame: 0, outFrame: 48, color: ball.color)
    }
    #expect(damagedReason(data) == "two layers share the id comp-2-layer-2")
}

@Test func anInPointAfterTheOutPointIsDamaged() throws {
    let data = try twoComps { state in
        let i = layerIndex("Badge", 0, state)
        state.compositions[0].layers[i].inFrame = 50
        state.compositions[0].layers[i].outFrame = 10
    }
    let reason = try #require(damagedReason(data))
    #expect(reason.contains("Badge") && reason.contains("50") && reason.contains("10"))
}

@Test func aTrackWithARepeatedFrameIsDamaged() throws {
    let data = try twoComps { state in
        let i = layerIndex("Ball", 1, state)
        state.compositions[1].layers[i].tracks["x"] = [
            HaloKeyframe(frame: 0, value: 1), HaloKeyframe(frame: 24, value: 2), HaloKeyframe(frame: 24, value: 3),
        ]
    }
    let reason = try #require(damagedReason(data))
    #expect(reason.contains("Ball") && reason.contains("x") && reason.contains("24"))
}

/// The reason `HaloFileValidation.check` gives for `two-comps` changed by
/// `change`; nil when it passes. JSON has no infinity (JSONEncoder refuses
/// it and JSONDecoder refuses 1e999), so non-finite values are checked on
/// the state itself.
private func checkReason(_ change: (inout HaloDocumentState) -> Void) throws -> String? {
    var state = try #require(HaloFixtures.project("two-comps"))
    change(&state)
    do {
        try HaloFileValidation.check(state)
        return nil
    } catch HaloFileError.damaged(let reason) {
        return reason
    }
}

@Test func anInfiniteKeyValueIsDamaged() throws {
    let reason = try #require(try checkReason { state in
        let i = layerIndex("Ball", 1, state)
        state.compositions[1].layers[i].tracks["x"] = [HaloKeyframe(frame: 0, value: .infinity)]
    })
    #expect(reason.contains("Ball") && reason.contains("x"))
    let data = try twoComps { state in
        state.compositions[1].layers[layerIndex("Ball", 1, state)].tracks["x"] = [HaloKeyframe(frame: 0, value: 123_456)]
    }
    let text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "123456", with: "1e999")
    #expect(damagedReason(Data(text.utf8)) != nil)
}

@Test func anInfiniteColorOrRectIsDamaged() throws {
    let color = try checkReason { state in
        state.compositions[1].layers[layerIndex("Floor", 1, state)].color.red = .nan
    }
    #expect(try #require(color).contains("Floor"))
    let rect = try checkReason { state in
        state.compositions[1].layers[layerIndex("Ball", 1, state)].rect?.width = -.infinity
    }
    #expect(try #require(rect).contains("Ball"))
}

@Test func aParentCycleIsDamaged() throws {
    let data = try twoComps { state in
        let ball = layerIndex("Ball", 1, state), floor = layerIndex("Floor", 1, state)
        state.compositions[1].layers[ball].parentID = state.compositions[1].layers[floor].id
        state.compositions[1].layers[floor].parentID = state.compositions[1].layers[ball].id
    }
    let reason = try #require(damagedReason(data))
    #expect(reason.contains("Ball") || reason.contains("Floor"))
    #expect(reason.contains("cycle"))
}

@Test func aParentFromAnotherCompositionIsDamaged() throws {
    let data = try twoComps { state in
        state.compositions[1].layers[layerIndex("Ball", 1, state)].parentID = "comp-1-layer-1"
    }
    let reason = try #require(damagedReason(data))
    #expect(reason.contains("Ball") && reason.contains("comp-1-layer-1"))
}

@Test func anUnknownSelectionIsDamaged() throws {
    let layer = try twoComps { $0.selectedLayerID = "nope" }
    #expect(try #require(damagedReason(layer)).contains("nope"))
    let comp = try twoComps { $0.selectedCompositionID = "gone" }
    #expect(try #require(damagedReason(comp)).contains("gone"))
}

@Test func openingRaisesTheCountersPastTheHighestId() throws {
    let data = try twoComps { state in
        let outro = state.compositions[1]
        state.compositions[1] = HaloComposition(
            id: "comp-5", name: outro.name, width: outro.width, height: outro.height,
            framesPerSecond: outro.framesPerSecond, durationFrames: outro.durationFrames, layers: outro.layers)
        state.nextCompositionNumber = 2
        state.compositions[0].layers[0] = state.compositions[0].layers[0].renamed(id: "comp-1-layer-9")
        state.nextLayerNumber = 3
    }
    let opened = try LiveProjectFiles().decode(data)
    #expect(opened.nextCompositionNumber == 6)
    #expect(opened.nextLayerNumber == 10)
}

@Test func countersAlreadyPastTheIdsStay() throws {
    let state = try #require(HaloFixtures.project("two-comps"))
    var ahead = state
    ahead.nextCompositionNumber = 40
    ahead.nextLayerNumber = 70
    #expect(try LiveProjectFiles().decode(LiveProjectFiles().encode(ahead)) == ahead)
}

@Test func aBareCompositionIsDamagedAndNamesAKey() throws {
    let data = Data(#"{"format":"halo","version":1,"project":{"compositions":[{"id":"a"}]}}"#.utf8)
    let reason = try #require(damagedReason(data))
    #expect(!reason.isEmpty)
    #expect(reason.contains("name"))
}

/// The damaged alert's reason reads as words: no brackets, no zero-based
/// index, no "JSON" (#1037 round 2).
@Test func aDecodingReasonDescribesThePlaceInWords() throws {
    let bare = Data(#"{"format":"halo","version":1,"project":{"compositions":[{"id":"a"}]}}"#.utf8)
    let reason = try #require(damagedReason(bare))
    #expect(!reason.contains("[") && !reason.contains("JSON"))
    #expect(reason.contains("first composition"))
    let text = String(decoding: try twoComps { _ in }, as: UTF8.self)
    let wrong = text.replacing(/"framesPerSecond":\d+/, with: #""framesPerSecond":"fast""#, maxReplacements: 1)
    #expect(wrong != text)
    let kind = try #require(damagedReason(Data(wrong.utf8)))
    #expect(kind == "the first composition's frames per second has a value of the wrong kind")
    let garbled = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad"))
    #expect(HaloFileFormat.reason(garbled) == "its contents can't be read")
}

@Test func codingKeysAndOrdinalsReadAsWords() {
    #expect(HaloFileFormat.words("framesPerSecond") == "frames per second")
    #expect(HaloFileFormat.words("parentID") == "parent id")
    #expect(HaloFileFormat.ordinal(3) == "third")
    #expect(HaloFileFormat.ordinal(12) == "12th")
    #expect(HaloFileFormat.ordinal(23) == "23rd")
}

@Test(arguments: HaloFixtures.names.filter { $0 != "huge" })
func everyFixturePassesTheChecks(name: String) throws {
    let fixture = try #require(HaloFixtures.project(name))
    #expect(try LiveProjectFiles().decode(LiveProjectFiles().encode(fixture)) == fixture)
}

extension HaloLayer {
    /// This layer under another id (the id is `let`).
    fileprivate func renamed(id: String) -> HaloLayer {
        var copy = HaloLayer(
            id: id, name: name, kind: kind, inFrame: inFrame, outFrame: outFrame, color: color, opacity: opacity,
            blendMode: blendMode, rect: rect)
        copy.tracks = tracks
        copy.parentID = parentID
        copy.text = text
        return copy
    }
}
