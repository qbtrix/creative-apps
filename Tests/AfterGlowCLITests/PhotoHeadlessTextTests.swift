// PhotoHeadlessTextTests.swift: `text.add` on a Photo document the CLI and MCP make draws its words, so the exported
// PNG differs from the blank one (#5193). Driven the way the router does it, through the registry's photo app. Core
// Text is macOS only: on Linux the headless text service stays PhotoServices' FakeText, which draws a clear frame.
import AfterGlowCLICore
import Testing

struct PhotoHeadlessTextTests {
    #if canImport(AppKit)
    @Test func textAddDrawsWordsInTheExport() throws {
        let photo = try #require(Apps.named("photo", in: CLI.registry))
        var session = try photo.session(new: .object(["width": .number(400), "height": .number(200)]))
        let blank = try #require(try session.export("png", options: .object([:])).first).data
        let words = JSONValue.object(["x": .number(40), "y": .number(60), "words": .string("SALE")])
        _ = try session.run(CommandEnvelope(id: "text.add", params: words))
        let drawn = try #require(try session.export("png", options: .object([:])).first).data
        #expect(drawn != blank, "text.add left the exported picture unchanged")
    }
    #endif
}
