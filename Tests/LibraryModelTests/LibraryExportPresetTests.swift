// LibraryExportPresetTests.swift: EX-10, export presets: the built-ins, add
// with a unique name, remove (never a built-in), apply keeps the folder, and
// the stored file. Written by EX-9, enabled by EX-10.
import Foundation
import Testing

@testable import LibraryModel

@Suite struct LibraryExportPresetTests {
    @Test func threeBuiltInsAllJPEG() {
        let builtIns = ExportPresets.builtIns
        #expect(builtIns.map(\.name) == ["For Sharing", "Full Size", "Small"])
        #expect(builtIns.map(\.longEdge) == [2048, nil, 1024])
        #expect(builtIns.map(\.quality) == [85, 95, 80])
        #expect(builtIns.allSatisfy { $0.format == .jpeg && $0.isBuiltIn })
        #expect(ExportPresets.unavailable == nil)
    }

    @Test func addingKeepsNamesUnique() {
        let web = ExportPreset(name: "Web 1200", options: ExportOptions(longEdge: 1200, quality: 70, folder: "/out"))
        let list = ExportPresets.adding(web, to: ExportPresets.adding(web, to: ExportPresets.builtIns))
        #expect(list.suffix(2).map(\.name) == ["Web 1200", "Web 1200 2"])
        #expect(Set(list.map(\.id)).count == list.count)
    }

    @Test func builtInsCantBeRemoved() {
        let builtIns = ExportPresets.builtIns
        for preset in builtIns { #expect(ExportPresets.removing(preset.id, from: builtIns) == builtIns) }
        let web = ExportPreset(name: "Web", options: ExportOptions(folder: "/out"))
        let list = ExportPresets.adding(web, to: builtIns)
        #expect(ExportPresets.removing(list.last?.id ?? "", from: list) == builtIns)
    }

    @Test func applyingKeepsTheFolder() throws {
        let sharing = try #require(ExportPresets.builtIns.first)
        let applied = sharing.applied(to: ExportOptions(longEdge: nil, quality: 50, folder: "/mine"))
        #expect(applied == ExportOptions(longEdge: 2048, quality: 85, folder: "/mine"))
    }

    @Test func fileRoundTripsAndDamagedDataGivesBuiltIns() {
        let last = ExportOptions(longEdge: 1200, quality: 70, folder: "/out", naming: ExportNaming(template: "{date}-{seq}"))
        let web = ExportPreset(name: "Web 1200", options: last)
        let file = ExportPresetFile(presets: ExportPresets.adding(web, to: ExportPresets.builtIns), last: last)
        #expect(ExportPresets.decode(ExportPresets.encode(file)) == file)
        let damaged = ExportPresets.decode(Data("not json".utf8))
        #expect(damaged.presets == ExportPresets.builtIns && damaged.last == nil)
        #expect(ExportPresets.decode(nil).last == nil)
    }
}
