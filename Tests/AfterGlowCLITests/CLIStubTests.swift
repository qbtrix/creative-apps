// CLIStubTests.swift: LJ0's second half (afterglow-cli CL-2). The app
// registry names the five apps in order and adds the fake only when asked;
// every entry point is real (CL-7 ScriptRunner, CL-9 RealJobs, MC-4 MCPServer);
// FakeIO round trips a file and never overwrites unless told to.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AfterGlowCLICore
import Testing

struct CLIStubTests {
    @Test func appsNameTheFiveAppsInOrder() {
        #expect(Apps.all.map(\.name) == ["photo", "design", "flare", "halo", "library"])
        #expect(Apps.named("halo", in: Apps.all)?.name == "halo")
        #expect(Apps.named("fake", in: Apps.all) == nil)
        #expect(Apps.named("fake", in: Apps.all + [Apps.fake])?.name == "fake")
        #expect(Apps.fake.openExtensions == ["fake"])
        #expect(Apps.fake.exportFormats == ["json"])
    }

    @Test func theFakeOpensAndSummarizesThroughItsSession() throws {
        let data = try FakeCanvasDocument.fixture.save()
        let session = try Apps.fake.session(open: data, name: "a.fake")
        #expect(session.app == "fake")
        #expect(session.summary() == .object(["rects": .number(2), "selected": .null]))
        #expect(try session.save() == data)
        #expect(try session.export("json", options: .object([:])).map(\.suggestedName) == ["canvas.json"])
        #expect(Apps.fake.describeAll().map(\.id) == FakeCanvasDocument.catalog.ids)
    }

    @Test func everyAppStubRefusesToOpenNamingItsSlice() {
        for app in Apps.all where app.describeAll().isEmpty { // an app whose slice filled its catalog opens for real
            #expect(throws: CatalogError.notBuilt(id: "open", feature: "adopt-command-catalog AC-\(app.name)")) {
                try app.session(open: Data(), name: "x")
            }
        }
    }

    @Test func fakeIORoundTripsAFile() throws {
        let io = FakeIO(files: ["in/b.fake": Data("b".utf8)])
        let bytes = Data("hello".utf8)
        try io.write(bytes, to: "in/a.fake", replace: false)
        #expect(try io.read("in/a.fake") == bytes)
        #expect(io.exists("in/a.fake"))
        #expect(throws: CLIIOError.exists("in/a.fake")) { try io.write(Data(), to: "in/a.fake", replace: false) }
        #expect(try io.read("in/a.fake") == bytes)
        try io.write(Data("again".utf8), to: "in/a.fake", replace: true)
        #expect(try io.read("in/a.fake") == Data("again".utf8))
        #expect(throws: CLIIOError.missing("in/c.fake")) { try io.read("in/c.fake") }
        #expect(!io.exists("in/c.fake"))
    }

    @Test func fakeIOGlobsWithinASegmentInSortedOrder() throws {
        let io = FakeIO(files: ["job/input/b.png": Data(), "job/input/a.png": Data(), "job/input/a.txt": Data(),
                                "job/input/deep/c.png": Data(), "other/input/d.png": Data()])
        #expect(try io.glob("input/*.png", relativeTo: "job") == ["job/input/a.png", "job/input/b.png"])
        #expect(try io.glob("input/?.txt", relativeTo: "job") == ["job/input/a.txt"])
        #expect(try io.glob("*/input/d.png", relativeTo: ".") == ["other/input/d.png"])
        #expect(try io.glob("input/*.gif", relativeTo: "job").isEmpty)
    }
}
