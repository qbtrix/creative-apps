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

/// LiveCommandChannel's rule for an answer to the sheet: a late or file-kind allow once holds nothing (#4811).
@Suite struct AIAccessAnswerTests {
    @Test func aLateAllowOnceDoesNotHoldTheConnection() {
        #expect(AIAccessGrants.holdsConnection(decision: .allowOnce, kind: "edit", waited: .seconds(109)))
        #expect(!AIAccessGrants.holdsConnection(decision: .allowOnce, kind: "edit", waited: .seconds(110)))
        #expect(!AIAccessGrants.holdsConnection(decision: .allowOnce, kind: "edit", waited: .seconds(111)))
        #expect(!AIAccessGrants.holdsConnection(decision: .allowOnce, kind: "file", waited: .seconds(1)))
        #expect(!AIAccessGrants.holdsConnection(decision: .alwaysForClient, kind: "edit", waited: .seconds(1)))
        #expect(!AIAccessGrants.holdsConnection(decision: .deny, kind: "edit", waited: .seconds(1)))
    }

    @Test func onlyATimelyAllowRunsTheCommandAskedAbout() {
        #expect(AIAccessGrants.answeredInTime(decision: .allowOnce, waited: .seconds(109)))
        #expect(AIAccessGrants.answeredInTime(decision: .alwaysForClient, waited: .zero))
        #expect(!AIAccessGrants.answeredInTime(decision: .allowOnce, waited: .seconds(110)))
        #expect(!AIAccessGrants.answeredInTime(decision: .alwaysForClient, waited: .seconds(111)))
        #expect(!AIAccessGrants.answeredInTime(decision: .deny, waited: .zero))
    }
}

/// The one front-window holder every editor's live channel reads and writes (#4810).
@MainActor @Suite struct LiveFrontTests {
    @Test func theLastRegisteredWindowIsFrontUntilItReleases() {
        let front = LiveFront<Int>()
        var landed: [String] = []
        let a = UUID(), b = UUID()
        #expect(front.document() == nil)
        front.register(a, read: { 1 }, write: { landed.append("a\($0)") })
        front.register(b, read: { 2 }, write: { landed.append("b\($0)") })
        front.release(a)
        #expect(front.window == b)
        #expect(front.document() == 2)
        front.apply(5)
        #expect(landed == ["b5"])
        front.release(b)
        #expect(front.window == nil)
        #expect(front.document() == nil)
        front.apply(6)
        #expect(landed == ["b5"])
    }

    @Test func aWindowBecomingActiveAgainTakesTheChannelBack() {
        let front = LiveFront<Int>()
        let a = UUID(), b = UUID()
        front.register(a, read: { 1 }, write: { _ in })
        front.register(b, read: { 2 }, write: { _ in })
        front.register(a, read: { 1 }, write: { _ in })
        front.release(b)
        #expect(front.document() == 1)
    }
}
