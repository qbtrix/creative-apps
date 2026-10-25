// HeadlessTextTests.swift: text the CLI and MCP add to a Photo or Halo document is drawn, so the exported PNG differs
// from the blank one (#5193 Photo's `text.add`, #5280 Halo's `text.set`). Driven the way the router does it, through
// the registry's apps. Core Text is macOS only: on Linux Photo's text stays FakeText (a clear frame) and Halo has no
// text rasterizer, so these run on macOS alone.
import AfterGlowCLICore
import Testing

struct HeadlessTextTests {
    #if canImport(AppKit)
    /// The PNG `session` exports with `options`.
    static func png(_ session: HeadlessSession, _ options: JSONValue = .object([:])) throws -> [UInt8] {
        Array(try #require(try session.export("png", options: options).first).data)
    }

    @Test func photoTextAddDrawsWordsInTheExport() throws {
        let photo = try #require(Apps.named("photo", in: CLI.registry))
        var session = try photo.session(new: .object(["width": .number(400), "height": .number(200)]))
        let blank = try Self.png(session)
        let words = JSONValue.object(["x": .number(40), "y": .number(60), "words": .string("SALE")])
        _ = try session.run(CommandEnvelope(id: "text.add", params: words))
        #expect(try Self.png(session) != blank, "text.add left the exported picture unchanged")
    }

    @Test func haloTextSetDrawsWordsInTheExport() throws {
        let halo = try #require(Apps.named("halo", in: CLI.registry))
        var session = try halo.session(new: .object(["width": .number(320), "height": .number(180)]))
        let frame = JSONValue.object(["frame": .number(0)])
        let blank = try Self.png(session, frame)
        _ = try session.run(CommandEnvelope(id: "layer.new", params: .object(["kind": .string("text")])))
        _ = try session.run(CommandEnvelope(id: "text.set", params: .object(["text": .string("Hello")])))
        _ = try session.run(CommandEnvelope(id: "text.set-size", params: .object(["size": .number(120)])))
        #expect(try Self.png(session, frame) != blank, "text.set left the exported frame unchanged")
    }
    #endif
}
