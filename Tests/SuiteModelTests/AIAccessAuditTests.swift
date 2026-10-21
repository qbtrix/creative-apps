// AIAccessAuditTests.swift (afterglow-mcp MC-10): the live channel's verdict
// runs only with a grant or this connection's allow once, never lets allow
// once cover a file command, and refuses a deny; an audit line is one JSON
// object on one line with the client, app, id, time and outcome, no params.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct AIAccessAuditTests {
    @Test func verdictRunsOnlyWithAGrantOrAllowOnce() {
        var grants = AIAccessGrants()
        #expect(grants.verdict(client: "c", app: "photo", kind: "edit", allowedOnce: false) == .ask)
        #expect(grants.verdict(client: "c", app: "photo", kind: "edit", allowedOnce: true) == .run)
        #expect(grants.verdict(client: "c", app: "photo", kind: "file", allowedOnce: true) == .ask)
        grants.record(.alwaysForClient, client: "c", app: "photo")
        #expect(grants.verdict(client: "c", app: "photo", kind: "query", allowedOnce: false) == .run)
        #expect(grants.verdict(client: "c", app: "photo", kind: "file", allowedOnce: false) == .ask)
        #expect(grants.verdict(client: "c", app: "flare", kind: "edit", allowedOnce: false) == .ask)
        grants.record(.deny, client: "c", app: "photo")
        #expect(grants.verdict(client: "c", app: "photo", kind: "edit", allowedOnce: true) == .refuse)
    }

    @Test func auditLineIsOneSortedObjectWithoutParams() throws {
        let line = AIAccessAuditLine(client: "evil\n{\"x\":1}", app: "photo", id: "layer.add",
                                     time: Date(timeIntervalSince1970: 0), outcome: "ran")
        let text = line.text
        #expect(text.hasSuffix("\n"))
        #expect(text.dropLast().contains("\n") == false)
        #expect(text.hasPrefix(#"{"app":"photo","client":"evil\n{\"x\":1}","id":"layer.add","outcome":"ran","time":"1970-01-01T00:00:00Z"}"#))
        #expect(try JSONDecoder().decode(AIAccessAuditLine.self, from: Data(text.utf8)) == line)
        #expect(AIAccessAuditLine.path(home: "/Users/a/") == "/Users/a/Library/Logs/AfterGlow/ai-access.log")
    }
}
