// ValuesExchangeTests.swift: colours keep their space, the asset index's
// revision moves on every add and update, and the clipboard envelope and
// round-trip session survive JSON.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct ValuesExchangeTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func ref(_ name: String, _ app: SuiteApp, _ type: SuiteTypeID) -> SuiteDocumentRef {
        let path = "/Users/me/Pictures/" + name
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: app,
                                type: type, displayName: name)
    }

    @Test func hexKeepsTheColourSpace() throws {
        let srgb = SuiteColorValue(space: .sRGB, red: 1, green: 0.5, blue: 0)
        let p3 = SuiteColorValue(space: .displayP3, red: 1, green: 0.5, blue: 0, alpha: 0.25)
        #expect(srgb.hex == "FF8000")
        #expect(p3.hex == "FF8000")
        #expect(srgb.space == .sRGB)
        #expect(p3.space == .displayP3)
        #expect(srgb != p3)
        #expect(SuiteColorValue(space: .sRGB, red: -1, green: 2, blue: 0.02).hex == "00FF05")
        let back = try JSONDecoder().decode(SuiteColorValue.self, from: JSONEncoder().encode(p3))
        #expect(back == p3)
        #expect(back.space == .displayP3)
        #expect(back.red == 1 && back.green == 0.5 && back.blue == 0 && back.alpha == 0.25)
    }

    @Test func addAndUpdateBumpTheRevision() {
        var index = AssetIndex()
        #expect(index.revision == 0 && index.assets.isEmpty)
        let red = SuiteColorValue(space: .displayP3, red: 1, green: 0, blue: 0)
        index.add(SuiteAsset(id: "a1", kind: .color, name: "Brand Red", color: red, modifiedAt: now))
        #expect(index.revision == 1)
        index.add(SuiteAsset(id: "a2", kind: .vector, name: "Logo", payload: "assets/a2/1.svg", modifiedAt: now + 1))
        #expect(index.revision == 2)
        #expect(index.assets.map(\.id) == ["a2", "a1"])

        let blue = SuiteColorValue(space: .displayP3, red: 0, green: 0, blue: 1)
        let updated = index.update("a1", at: now + 2, color: blue)
        #expect(updated?.revision == 2)
        #expect(updated?.color == blue)
        #expect(updated?.color?.space == .displayP3)
        #expect(updated?.modifiedAt == now + 2)
        #expect(index.asset("a1") == updated)
        #expect(index.revision == 3)

        let logo = index.update("a2", at: now + 3, payload: "assets/a2/2.svg")
        #expect(logo?.revision == 2 && logo?.payload == "assets/a2/2.svg")
        #expect(index.revision == 4)

        #expect(index.update("gone", at: now + 4) == nil)
        #expect(index.revision == 4)
        #expect(index.search("logo", kind: nil).map(\.id) == ["a2"])
        #expect(index.search("", kind: .color).map(\.id) == ["a1"])
    }

    @Test func mergeKeepsTheHigherRevision() {
        var mine = AssetIndex()
        mine.add(SuiteAsset(id: "a1", kind: .vector, name: "Logo", modifiedAt: now))
        var theirs = mine
        _ = theirs.update("a1", at: now + 1, payload: "assets/a1/2.svg")
        let merged = mine.merging(theirs)
        #expect(merged.asset("a1")?.revision == 2)
        #expect(merged.revision == 2)
    }

    @Test func envelopeSurvivesJSON() throws {
        let envelope = AssetEnvelope(name: "Brand Red", kind: .color, from: .design,
                                     link: AssetLink(assetID: "a1", kind: .color, placedRevision: 3),
                                     color: SuiteColorValue(space: .displayP3, red: 0.9, green: 0.1, blue: 0.2))
        let back = try JSONDecoder().decode(AssetEnvelope.self, from: JSONEncoder().encode(envelope))
        #expect(back == envelope)
        #expect(back.color?.space == .displayP3)
        let svg = AssetEnvelope(name: "Logo", kind: .vector, from: .flare, svg: "<svg/>")
        #expect(try JSONDecoder().decode(AssetEnvelope.self, from: JSONEncoder().encode(svg)) == svg)
        #expect(SuiteClipItem.envelope(envelope).kindName == "colours")
        #expect(SuiteClipItem.envelope(svg).kindName == "vector art")
        #expect(SuiteClipItem.image(png: Data(), pixelWidth: 1, pixelHeight: 1).kindName == "images")
        #expect(SuiteClipItem.files([]).kindName == "files")
        #expect(TypedData(type: .assetEnvelope, data: Data([1])).type == .assetEnvelope)
    }

    @Test func roundTripSessionSurvivesJSON() throws {
        let original = ref("IMG_0002.jpg", .library, .jpeg)
        let session = RoundTripSession(
            id: "r1", source: RoundTripSource(catalogPhotoID: "p2", original: original),
            title: "IMG_0002 (Library edit)",
            state: .saved(flattened: ref("IMG_0002 edit 1.png", .photo, .png),
                          layered: ref("IMG_0002 edit 1.ora", .photo, .photoOpenRaster)),
            startedAt: now)
        let back = try JSONDecoder().decode(RoundTripSession.self, from: JSONEncoder().encode(session))
        #expect(back == session)
        #expect(back.source.original == original)
    }
}
