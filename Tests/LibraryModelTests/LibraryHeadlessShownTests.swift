// LibraryHeadlessShownTests.swift (command-state CS-15, RJ-X61): the "shown" json export reports Show Original
// while it is on and leaves the field out once it is off, so an agent reads the toggle's state back. Linux-safe.
import Foundation
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryHeadlessShownTests {
    static let shown = JSONValue.object(["contents": .string("shown")])

    static func shownJSON(_ doc: LibraryHeadless) throws -> JSONValue {
        try JSONValue(json: #require(doc.export("json", options: shown).first?.data))
    }

    @Test func showOriginalReadsBackOnThenOff() throws {
        var doc = try LibraryHeadless.open(LibraryHeadlessTests.input("cull-and-save"), name: "shoot.library")
        let names: JSONValue = .array(["beach.png", "dock.png", "fog.png", "pier.png"].map { .string($0) })
        #expect(try Self.shownJSON(doc) == .object(["shown": names]))
        _ = try LibraryHeadless.catalog.run("view.loupe", params: .object([:]), on: &doc)
        #expect(doc.library.showOriginalHelp == nil)
        let on = try LibraryHeadless.catalog.run("view.show-original", params: .object([:]), on: &doc)
        #expect(on.result == .object(["on": .bool(true)]))
        #expect(try Self.shownJSON(doc) == .object(["original": .bool(true), "shown": names]))
        let off = try LibraryHeadless.catalog.run("view.show-original", params: .object([:]), on: &doc)
        #expect(off.result == .object(["on": .bool(false)]))
        #expect(try Self.shownJSON(doc) == .object(["shown": names]))
    }
}
