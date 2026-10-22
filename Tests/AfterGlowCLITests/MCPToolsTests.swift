// MCPToolsTests.swift: MJ2's tool-list checks (afterglow-mcp MC-5, written
// first; MC-6 builds `MCPTools.list` and `route` and turns them on).
// `tools/list` publishes the session tools first (`<app>.open`, `<app>.new`,
// `afterglow.save`, `afterglow.export`, `afterglow.close`), then one
// `<app>.<id>` tool per catalog command in id order, each with a valid,
// unique name, the command's title and summary, input `{doc, params}` with
// the command's params schema nested under `params`, an output schema, and
// annotations from the command's kind. The list is the same on every call,
// holds only the apps it is given (`--app`), and every name routes back.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import AfterGlowCLICore
import Testing

struct MCPToolsTests {
    static let session = ["afterglow.save", "afterglow.export", "afterglow.close"]
    static let fakeCommands = Apps.fake.describeAll()

    static func field(_ value: JSONValue?, _ key: String) -> JSONValue? { if case .object(let o)? = value { o[key] } else { nil } }
    /// The strings in the array `value`, as a set; empty when it isn't one.
    static func strings(_ value: JSONValue?) -> Set<String> {
        guard case .array(let items)? = value else { return [] }
        return Set(items.compactMap { item -> String? in if case .string(let text) = item { text } else { nil } })
    }
    static func tool(_ name: String, in tools: [MCPTool]) throws -> MCPTool { try #require(tools.first { $0.name == name }, "\(name)") }
    /// Whether `name` is a valid MCP tool name: 1 to 128 of letters, digits, `_`, `-` and `.`.
    static func isValidName(_ name: String) -> Bool {
        (1...128).contains(name.count) && name.unicodeScalars.allSatisfy {
            ("a"..."z").contains($0) || ("A"..."Z").contains($0) || ("0"..."9").contains($0) || "_-.".unicodeScalars.contains($0)
        }
    }

    @Test
    func theFakeListsItsSessionToolsThenOneToolPerCommandInIDOrder() {
        let names = MCPTools.list([Apps.fake]).map(\.name)
        #expect(Self.fakeCommands.map(\.id) == Self.fakeCommands.map(\.id).sorted() && Self.fakeCommands.count == 21)
        #expect(names == ["fake.open", "fake.new"] + Self.session + Self.fakeCommands.map { "fake.\($0.id)" })
    }

    @Test
    func everyAppGetsItsSessionToolsFirstAndItsCommandsGroupedByID() {
        let apps = Apps.all + [Apps.fake]
        let tools = MCPTools.list(apps).map(\.name)
        let commands = apps.flatMap { app in app.describeAll().map { MCPTools.name(app: app.name, command: $0.id) } }
        #expect(tools.count == 2 * apps.count + Self.session.count + commands.count)
        let head = tools.prefix(2 * apps.count + Self.session.count)
        #expect(Set(head) == Set(apps.flatMap { ["\($0.name).open", "\($0.name).new"] } + Self.session))
        #expect(Array(tools.dropFirst(head.count)) == commands)
        for app in apps { #expect(app.describeAll().map(\.id) == app.describeAll().map(\.id).sorted(), "\(app.name)") }
    }

    @Test
    func namesAreValidAndUnique() {
        let names = MCPTools.list(Apps.all + [Apps.fake]).map(\.name)
        #expect(Set(names).count == names.count)
        for name in names { #expect(Self.isValidName(name), "\(name)") }
        #expect(!Self.isValidName("") && !Self.isValidName("a b") && !Self.isValidName(String(repeating: "a", count: 129)))
    }

    @Test
    func stableOrder() {
        let first = MCPTools.list(Apps.all + [Apps.fake])
        for _ in 0..<5 { #expect(MCPTools.list(Apps.all + [Apps.fake]) == first) }
        #expect(MCPTools.list([Apps.fake]) == MCPTools.list([Apps.fake]))
    }

    @Test
    func theAppFilterListsOnlyTheGivenApps() {
        let fakeOnly = MCPTools.list([Apps.fake]).map(\.name)
        #expect(fakeOnly.allSatisfy { $0.hasPrefix("fake.") || $0.hasPrefix("afterglow.") })
        let all = Set(MCPTools.list(Apps.all + [Apps.fake]).map(\.name))
        #expect(Set(fakeOnly).isSubset(of: all) && all.contains("photo.open") && !fakeOnly.contains("photo.open"))
        #expect(MCPTools.list([]).map(\.name) == Self.session)
    }

    @Test
    func paramsNested() throws {
        let tools = MCPTools.list([Apps.fake])
        for command in Self.fakeCommands {
            let schema = try Self.tool("fake.\(command.id)", in: tools).inputSchema
            #expect(Self.field(schema, "type") == .string("object"))
            #expect(Self.field(Self.field(schema, "properties"), "params") == command.params, "\(command.id)")
            #expect(Self.field(Self.field(Self.field(schema, "properties"), "doc"), "type") == .string("string"))
            #expect(Self.strings(Self.field(schema, "required")).contains("doc"))
            #expect(Self.field(Self.field(schema, "properties"), "x") == nil, "params inlined in \(command.id)")
        }
    }

    @Test
    func sessionToolsTakeTheirDocumentedArguments() throws {
        let tools = MCPTools.list([Apps.fake])
        let expected: [String: (all: Set<String>, required: Set<String>)] = [
            "fake.open": (["path"], ["path"]), "fake.new": (["options"], []),
            "afterglow.save": (["doc", "path", "force"], ["doc"]),
            "afterglow.export": (["doc", "format", "path", "options", "force"], ["doc", "format", "path"]),
            "afterglow.close": (["doc"], ["doc"]),
        ]
        for (name, want) in expected {
            let schema = try Self.tool(name, in: tools).inputSchema
            guard case .object(let properties)? = Self.field(schema, "properties") else { Issue.record("\(name)"); continue }
            #expect(Set(properties.keys) == want.all, "\(name)")
            #expect(Self.strings(Self.field(schema, "required")) == want.required, "\(name)")
        }
    }

    @Test
    func titlesAndDescriptionsComeFromTheCommand() throws {
        let tools = MCPTools.list([Apps.fake])
        for command in Self.fakeCommands {
            let tool = try Self.tool("fake.\(command.id)", in: tools)
            #expect(tool.title == command.title && tool.description.hasPrefix(command.summary))
            let undoable = "Undoable: one step named '\(command.title)'."
            #expect(tool.description.contains(undoable) == (command.kind == .edit), "\(command.id)")
        }
        #expect(try Self.tool("fake.open", in: tools).description.contains("handles expire after 1 hour idle; at most 16 open"))
    }

    @Test
    func everyToolHasAnObjectOutputSchema() throws {
        let tools = MCPTools.list([Apps.fake])
        for tool in tools { #expect(Self.field(tool.outputSchema, "type") == .string("object"), "\(tool.name)") }
        let open = Self.field(try Self.tool("fake.open", in: tools).outputSchema, "properties")
        #expect(Self.field(open, "doc") != nil && Self.field(open, "summary") != nil)
        #expect(Self.field(Self.field(try Self.tool("fake.rect.add", in: tools).outputSchema, "properties"), "undoStep") != nil)
    }

    @Test
    func readOnlyFromKind() throws {
        let tools = MCPTools.list([Apps.fake])
        for command in Self.fakeCommands {
            let annotations = try Self.tool("fake.\(command.id)", in: tools).annotations
            #expect(Self.field(annotations, "openWorldHint") == .bool(false), "\(command.id)")
            switch command.kind {
            case .query: #expect(Self.field(annotations, "readOnlyHint") == .bool(true), "\(command.id)")
            case .view, .edit:
                #expect(Self.field(annotations, "readOnlyHint") == .bool(false), "\(command.id)")
                #expect(Self.field(annotations, "destructiveHint") == .bool(false), "\(command.id)")
            case .file: #expect(Self.field(annotations, "readOnlyHint") != .bool(true), "\(command.id)")
            }
        }
        #expect(Set(Self.fakeCommands.map(\.kind)) == [.query, .view, .edit, .file])
        for name in ["afterglow.save", "afterglow.export"] {
            #expect(Self.field(try Self.tool(name, in: tools).annotations, "destructiveHint") == .bool(true), "\(name)")
        }
        for tool in tools { #expect(Self.field(tool.annotations, "openWorldHint") == .bool(false), "\(tool.name)") }
    }

    @Test
    func everyNameRoutesBackAndUnknownNamesDont() {
        let apps = Apps.all + [Apps.fake]
        for tool in MCPTools.list(apps) { #expect(MCPTools.route(tool.name, in: apps) != nil, "\(tool.name)") }
        #expect(MCPTools.route("fake.open", in: apps) == .open(app: "fake"))
        #expect(MCPTools.route("photo.new", in: apps) == .new(app: "photo"))
        #expect(MCPTools.route("afterglow.save", in: apps) == .save)
        #expect(MCPTools.route("afterglow.export", in: apps) == .export)
        #expect(MCPTools.route("afterglow.close", in: apps) == .close)
        #expect(MCPTools.route("fake.rect.add", in: apps) == .command(app: "fake", id: "rect.add"))
        for unknown in ["fake.nope", "afterglow.open", "fake", "", "fake.rect", "nope.rect.add", "fake.rect.add.x"] {
            #expect(MCPTools.route(unknown, in: apps) == nil, "\(unknown)")
        }
        #expect(MCPTools.route("fake.rect.add", in: Apps.all) == nil)
    }

    @Test func toolsListThroughTheServerMatchesTheList() throws {
        let server = MCPServer(MCPOptions(apps: [Apps.fake], roots: ["/tmp/mcp"]), io: FakeIO(), clock: { 0 })
        var client = MCPTestClient(server, era: .sessionless(MCPVersions.current))
        guard case .array(let tools)? = Self.field(try client.request("tools/list").result, "tools") else {
            Issue.record("no tools"); return
        }
        let listed = try tools.map { try JSONDecoder().decode(MCPTool.self, from: JSONEncoder().encode($0)) }
        #expect(listed == MCPTools.list([Apps.fake]))
        let list = try Self.tool("fake.rect.list", in: listed)
        #expect(Self.field(list.annotations, "readOnlyHint") == .bool(true))
    }

    /// Timing (quality row "list latency"): reported, not gated, so it waits on a `Tests/perf-suites.txt` entry too.
    @Test(.disabled("waits on MC-6 and a perf-suites entry (timing)"))
    func listWithinBudget() {
        let apps = Apps.all
        _ = MCPTools.list(apps)
        let clock = ContinuousClock()
        let took = clock.measure { _ = MCPTools.list(apps) }
        #expect(took <= .milliseconds(50))
    }
}
