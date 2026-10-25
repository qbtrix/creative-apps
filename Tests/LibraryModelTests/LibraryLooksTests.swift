// LibraryLooksTests.swift (adjust-everywhere AJ-10): Library's catalog as an
// AdjustTarget. Black & White and Invert are kept in a photo's develop
// settings under the keys `bw` and `invert`; a catalog written before them
// opens and saves byte for byte; a look on 40 selected photos is one step that
// changes all 40; the filter commands are off with "Filters are in Photo.".
// Mutations: LibraryModel.LibraryLooks+Kernel (`.wholeSelection`,
// `.oldCatalogBytesUnchanged`). Linux-safe.
import Foundation
@testable import LibraryModel
import SuiteImaging
import SuiteKernel
import SuiteModel
import Testing

@Suite struct LibraryLooksTests {
    static let catalog = LibraryCatalog.catalog
    static let warm = GrayWeights(red: 120, yellow: 60, green: 40, cyan: 60, blue: 20, magenta: 80)

    /// `count` photos, every one selected, in the grid.
    static func selected(_ count: Int) -> LibraryCatalog {
        let photos = LibraryFixtures.largePhotos(count: count, folder: nil)
        var c = LibraryCatalog(services: .fake(photos))
        c.load(photos)
        c.select(Set(photos.map(\.id)))
        return c
    }

    static func weights(_ w: GrayWeights) -> JSONValue {
        .object(["weights": .object(["red": .number(w.red), "yellow": .number(w.yellow), "green": .number(w.green),
                                     "cyan": .number(w.cyan), "blue": .number(w.blue), "magenta": .number(w.magenta)])])
    }

    static func json(_ s: DevelopSettings) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try JSONSerialization.jsonObject(with: encoder.encode(s)) as? [String: Any] ?? [:]
    }

    @Test func kindsKeptUnderNewKeys() throws {
        let s = DevelopSettings.neutral.setting(kinds: [.blackAndWhite(Self.warm), .invert])
        let keys = try Self.json(s)
        #expect(keys["bw"] != nil && keys["invert"] as? Bool == true)
        let back = try JSONDecoder().decode(DevelopSettings.self, from: JSONEncoder().encode(s))
        #expect(back == s && back.kinds == [.blackAndWhite(Self.warm), .invert])
        #expect(!s.isAdjustmentNeutral && DevelopSettings.neutral.setting(kinds: []).isNeutral)
    }

    /// A develop record from before the kinds opens in colour and writes the same bytes back.
    @Test func oldCatalogBytesUnchanged() throws {
        let old = Data(#"{"contrast":13,"exposure":1,"highlights":0,"shadows":0,"temperature":0,"tint":0}"#.utf8)
        let s = try JSONDecoder().decode(DevelopSettings.self, from: old)
        #expect(s.kinds.isEmpty && s.value(.exposure) == 1)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(try encoder.encode(s) == old)
        var c = Self.selected(3)
        c.setDevelop(.exposure, to: 1, coalesceKey: nil)
        let bytes = try LiveCatalogCoding().encode(c.items)
        #expect(try LiveCatalogCoding().encode(LiveCatalogCoding().decode(bytes)) == bytes)
        #expect(!String(decoding: bytes, as: UTF8.self).contains("\"bw\""))
    }

    /// A look on 40 selected photos: one "Apply Look" step, every photo grey; Undo puts all 40 back.
    @Test func wholeSelection() throws {
        var c = Self.selected(40)
        let steps = c.history.undo.count
        let run = try Self.catalog.run("look.apply", params: .object(["id": .string("bw")]), on: &c)
        #expect(run.undoStep == "Apply Look" && c.history.undo.count == steps + 1)
        #expect(c.items.allSatisfy { $0.develop.kinds == [.blackAndWhite(.neutral)] })
        c.undo()
        #expect(c.items.allSatisfy { $0.develop.isNeutral })
    }

    /// A look sets the sliders, levels and kinds it carries; currentLook reads them back.
    @Test func lookSetsDevelop() throws {
        var c = Self.selected(2)
        _ = try Self.catalog.run("look.apply", params: .object(["id": .string("bw-high-contrast")]), on: &c)
        #expect(c.items.allSatisfy { $0.develop.value(.contrast) == 40 && $0.develop.value(.blacks) == -20 })
        _ = try Self.catalog.run("look.apply", params: .object(["id": .string("fade")]), on: &c)
        #expect(c.items.allSatisfy { $0.develop.kinds.isEmpty && $0.develop.value(.contrast) == -15 })
        #expect(c.currentLook.tone.value(.contrast) == -15 && c.currentLook.adjust.levels.outputBlack == 0.08)
    }

    @Test func kindsByCommand() throws {
        var c = Self.selected(2)
        #expect(try Self.catalog.run("adjust.black-and-white", params: Self.weights(Self.warm), on: &c).undoStep == "Black & White")
        #expect(try Self.catalog.run("adjust.invert", params: .object([:]), on: &c).undoStep == "Invert")
        #expect(c.kinds == [.blackAndWhite(Self.warm), .invert])
        #expect(c.items.allSatisfy { $0.develop.kinds == c.kinds })
        _ = try Self.catalog.run("adjust.black-and-white", params: .object([:]), on: &c)
        #expect(c.kinds == [.invert])
    }

    @Test func filtersAreInPhoto() {
        let c = Self.selected(1)
        for id in ImagingFilter.ids {
            #expect(Self.catalog.availability("filter.\(id)", on: c).why == "Filters are in Photo.")
        }
        #expect(Self.catalog.availability("adjust.invert", on: LibraryCatalog()).why == "Select a photo to develop it.")
        #expect(Self.catalog.availability("look.apply", on: c).why == nil)
    }

    /// Save Look keeps the photo's develop as a look on the catalog's store, listed after the built-ins.
    @Test func saveLook() throws {
        var c = Self.selected(1)
        c.setDevelop(.contrast, to: 20, coalesceKey: nil)
        _ = try Self.catalog.run("look.save", params: .object(["name": .string("Mine")]), on: &c)
        let mine = LookPreset.find("mine", in: c.looks)
        #expect(mine?.tone.value(.contrast) == 20)
        #expect(LookPreset.all(in: c.looks).count == BuiltInLooks.all.count + 1)
    }
}
