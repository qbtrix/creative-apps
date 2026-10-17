// DesignLiveStubTests.swift: the tier-1 live stubs before their features fill
// them (D0-2b). LiveOrdering (LiveStyling left with style-rows ST-1, LiveGrouping
// with copy-group C-2, LiveDuplicating with C-1, LiveClipboard with C-3) answers every help and every refusal
// exactly as NotBuilt with their 5.6 name, on `cards` with A, and with A and B.
// LiveFiling is today's codec: it saves `cards` to the bytes DesignFile writes,
// opens them back to the same pages, and refuses what DesignFile refuses with
// the same reason. `.live` holds the ten Live types plus LiveExport (the export
// plan and SVG text, DesignExport+Kernel), obeys the help law, and MJ3 walks
// every slot of it on `cards`. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

@Suite struct DesignLiveStubTests {
    let workspace = DesignFixtures.cards
    var page: DesignPage { workspace.selectedPage ?? DesignPage(id: "none", name: "None", frameWidth: 1, frameHeight: 1) }
    static let selections = [["node-2"], ["node-2", "node-3"]]  // A; A and B

    /// What `body` threw as a refusal; nil when it returned (or threw something else).
    private func refusal(_ body: () throws -> Void) -> DesignRefusal? {
        do { try body() } catch { return error as? DesignRefusal }
        return nil
    }

    /// Each help and each write of the forwarding stub, as the stub answers and as NotBuilt
    /// with `name` answers, so a pair differs exactly when the stub stops forwarding.
    private func answers(_ ids: [String]) -> [(stub: String, notBuilt: String, name: String)] {
        func help(_ name: String, _ stub: String?, _ base: String?) -> (String, String, String) {
            ("\(stub ?? "nil")", "\(base ?? "nil")", name)
        }
        func write(_ name: String, _ stub: () throws -> Void, _ base: () throws -> Void) -> (String, String, String) {
            ("\(String(describing: refusal(stub)))", "\(String(describing: refusal(base)))", name)
        }
        let (order, no) = (LiveOrdering(), NotBuilt("Reordering layers"))
        var rows: [(String, String, String)] = []
        for id in ids {
            rows.append(help("Reordering layers", order.moveHelp(id, into: "node-1", at: 0, on: page),
                             no.moveHelp(id, into: "node-1", at: 0, on: page)))
            rows.append(write("Reordering layers", { _ = try order.move(id, into: "node-1", at: 0, on: page) },
                              { _ = try no.move(id, into: "node-1", at: 0, on: page) }))
        }
        for step in [DesignArrangeStep.bringToFront, .sendToBack] {
            rows.append(help("Reordering layers", order.arrangeHelp(step, ids, on: page), no.arrangeHelp(step, ids, on: page)))
            rows.append(write("Reordering layers", { _ = try order.arrange(step, ids, on: page) },
                              { _ = try no.arrange(step, ids, on: page) }))
        }
        return rows
    }

    @Test(arguments: selections) func stubsAnswerAsNotBuilt(_ ids: [String]) {
        #expect(page.nodes.node("node-2")?.name == "A")
        let rows = answers(ids)
        #expect(rows.count >= 6)
        for row in rows { #expect(row.stub == row.notBuilt, "\(row.name)") }
    }

    @Test(arguments: selections) func stubsRefuseWithTheirName(_ ids: [String]) {
        var mint = DesignIDMint(taken: [], after: 10)
        let refusals: [(DesignRefusal?, String)] = [
            (refusal { _ = try LiveOrdering().arrange(.bringForward, ids, on: page) }, "Reordering layers"),
        ]
        for (thrown, name) in refusals { #expect(thrown == .notBuilt(name)) }
        let helps: [(String?, String)] = [
            (LiveOrdering().arrangeHelp(.sendBackward, ids, on: page), "Reordering layers"),
        ]
        for (help, name) in helps { #expect(help == "\(name) isn't built yet.") }
        #expect(mint.minted.isEmpty)
    }

    @Test func filingSavesTodaysBytes() throws {
        let filing = LiveFiling()
        let today = try workspace.fileData()
        let saved = try filing.encode(DesignDocument(pages: workspace.pages))
        #expect(saved == today)
        let reopened = try filing.decode(saved)
        #expect(reopened == DesignDocument(pages: workspace.pages))
        #expect(try filing.encode(reopened) == today)
    }

    @Test func filingRefusesWithDesignFilesReason() {
        let bytes = Data("not json".utf8)
        var today = DesignWorkspace()
        let expected: DesignFileError?
        do { try today.open(bytes); expected = nil } catch { expected = error }
        let thrown: DesignFileError?
        do { _ = try LiveFiling().decode(bytes); thrown = nil } catch { thrown = error }
        #expect(expected == .unreadable)
        #expect(thrown == expected)
        #expect(thrown?.reason == "It is not a Design file.")
    }

    @Test func filingRefusesWhatDecodeRefuses() {
        let a = page.nodes.node("node-2") ?? DesignNode(id: "x", name: "x", kind: .rectangle, frame: rc(0, 0, 1, 1))
        var twice = page
        twice.nodes.append(a)
        let encode: DesignFileError?
        do { _ = try LiveFiling().encode(DesignDocument(pages: [twice])); encode = nil } catch { encode = error }
        #expect(encode == .duplicateID("node-2"))
        let version: DesignFileError?
        do { _ = try LiveFiling().decode(Data(#"{"pages":[],"version":2}"#.utf8)); version = nil } catch { version = error }
        #expect(version == .unsupportedVersion(2))
        let empty: DesignFileError?
        do { _ = try LiveFiling().decode(Data(#"{"pages":[],"version":1}"#.utf8)); empty = nil } catch { empty = error }
        #expect(empty == .noPages)
    }

    @Test func liveSlotsAreTheLiveTypes() {
        let live = DesignServices.live
        #expect(live.marquee is LiveMarquee && live.transforming is LiveTransforming)
        #expect(live.aligning is LiveAligning && live.framing is LiveFraming)
        #expect(live.duplicating is LiveDuplicating && live.grouping is LiveGrouping)
        #expect(live.clipboard is LiveClipboard && live.ordering is LiveOrdering)
        #expect(live.styling is LiveStyling && live.filing is LiveFiling)
        #expect(live.export is LiveExport)
        let tier2: [(Any, String)] = [(live.pen, "The Pen tool"), (live.components, "Components"), (live.variables, "Variables")]
        for (slot, name) in tier2 { #expect((slot as? NotBuilt)?.feature == name) }
    }

    @Test func helpLawHoldsOnLive() {
        let law = DesignContractLaw.check(.live, on: page)
        #expect(law.checks == 66 * DesignContractLaw.selections.count)
        #expect(law.violations.isEmpty, "\(law.violations)")
    }

    /// MJ3: open `cards`; every `.live` slot answers its NotBuilt help and refusal, except the eight
    /// with live paths (their Live types, obeying the law), filing, which saves and reopens `cards`,
    /// and export, which plans A and B as PNGs and gives an SVG document.
    @Test func testLiveStubsWalk() throws {
        var opened = DesignWorkspace()
        try opened.open(DesignFixtures.cards.fileData())
        let page = try #require(opened.selectedPage)
        let live = DesignServices.live
        let ids = ["node-2", "node-3"]
        var mint = DesignIDMint(taken: [], after: 10)
        let helps: [(String?, String)] = [
            (live.ordering.arrangeHelp(.bringToFront, ids, on: page), "Reordering layers"),
            (live.components.createHelp(ids, on: page), "Components"),
        ]
        for (help, name) in helps { #expect(help == "\(name) isn't built yet.") }
        let path = DesignPath(anchors: [DesignAnchor(point: pt(0, 0)), DesignAnchor(point: pt(10, 10))], isClosed: false)
        let writes: [(DesignRefusal?, String)] = [
            (refusal { _ = try live.ordering.arrange(.sendToBack, ids, on: page) }, "Reordering layers"),
            (refusal { _ = try live.pen.commit(path, into: nil, on: page, mint: &mint) }, "The Pen tool"),
            (refusal { _ = try live.components.create(from: "node-1", on: page, library: [], mint: &mint) }, "Components"),
            (refusal { _ = try live.variables.remove("v", from: []) }, "Variables"),
        ]
        for (thrown, name) in writes { #expect(thrown == .notBuilt(name)) }
        #expect(mint.minted.isEmpty)
        // The eight live paths (grouping since C-2, duplicating since C-1, clipboard since C-3): their own types, acting as their features define, within the law.
        #expect(live.marquee is LiveMarquee && live.transforming is LiveTransforming)
        #expect(live.aligning is LiveAligning && live.framing is LiveFraming && live.styling is LiveStyling)
        #expect(live.transforming.transformHelp(ids, on: page) == nil)
        #expect(live.framing.rectToShow(ids, on: page) != nil)
        #expect(live.styling.styleHelp(.opacity, ids, on: page) == nil)
        #expect(live.grouping is LiveGrouping && live.grouping.groupHelp(ids, on: page) == nil)
        #expect(live.duplicating is LiveDuplicating && live.duplicating.duplicateHelp(ids, on: page) == nil)
        #expect(live.clipboard is LiveClipboard && live.clipboard.copyHelp(ids, on: page) == nil)
        let law = DesignContractLaw.check(live, on: page)
        #expect(law.violations.isEmpty, "\(law.violations)")
        // Export plans the named layers and gives an SVG document; its help is nil exactly when the plan succeeds.
        #expect(live.export is LiveExport && live.export.exportHelp(ids, on: page) == nil)
        #expect(try live.export.plan(ids, on: page, format: .png, scale: 2, existing: []).map(\.fileName) == ["A.png", "B.png"])
        #expect(try live.export.svg(for: "node-2", on: page).hasPrefix("<svg"))
        #expect(live.export.exportHelp(["nope"], on: page) == "Select a layer first.")
        // Filing saves `cards` to today's bytes and reopens it to the same pages.
        let today = try opened.fileData()
        let saved = try live.filing.encode(DesignDocument(pages: opened.pages))
        #expect(saved == today)
        #expect(try live.filing.decode(saved) == DesignDocument(pages: opened.pages))
        #expect(throws: DesignFileError.unreadable) { try live.filing.decode(Data("not json".utf8)) }
    }
}
