// DesignLiveStubTests.swift: the tier-1 live stubs before their features fill
// them (D0-2b). LiveDuplicating, LiveGrouping, LiveClipboard, LiveOrdering and
// LiveStyling answer every help and every refusal exactly as NotBuilt with
// their 5.6 name, on DesignFixtures' `cards` with A selected and with A and B.
// LiveFiling is today's codec: it saves `cards` to the bytes DesignFile writes,
// opens them back to the same pages, and refuses what DesignFile refuses with
// the same reason. Runs on Linux and macOS.
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

    /// Each help and each write of the five forwarding stubs, as the stub answers and as NotBuilt
    /// with `name` answers, so a pair differs exactly when the stub stops forwarding.
    private func answers(_ ids: [String]) -> [(stub: String, notBuilt: String, name: String)] {
        let delta = pt(10, 10)
        let bytes = Data("{}".utf8)
        func help(_ name: String, _ stub: String?, _ base: String?) -> (String, String, String) {
            ("\(stub ?? "nil")", "\(base ?? "nil")", name)
        }
        func write(_ name: String, _ stub: () throws -> Void, _ base: () throws -> Void) -> (String, String, String) {
            ("\(String(describing: refusal(stub)))", "\(String(describing: refusal(base)))", name)
        }
        var mint = DesignIDMint(taken: [], after: 10)
        let (dup, group, clip, order, style) = (LiveDuplicating(), LiveGrouping(), LiveClipboard(), LiveOrdering(), LiveStyling())
        let (nd, ng, nc, no, ns) = (NotBuilt("Duplicate"), NotBuilt("Group"), NotBuilt("Copy and paste"),
                                     NotBuilt("Reordering layers"), NotBuilt("Style editing"))
        var rows = [
            help("Duplicate", dup.duplicateHelp(ids, on: page), nd.duplicateHelp(ids, on: page)),
            write("Duplicate", { _ = try dup.duplicate(ids, offset: delta, on: page, mint: &mint) },
                  { _ = try nd.duplicate(ids, offset: delta, on: page, mint: &mint) }),
            help("Group", group.groupHelp(ids, on: page), ng.groupHelp(ids, on: page)),
            help("Group", group.ungroupHelp(ids, on: page), ng.ungroupHelp(ids, on: page)),
            write("Group", { _ = try group.group(ids, on: page, mint: &mint) }, { _ = try ng.group(ids, on: page, mint: &mint) }),
            write("Group", { _ = try group.ungroup(ids, on: page) }, { _ = try ng.ungroup(ids, on: page) }),
            help("Copy and paste", clip.copyHelp(ids, on: page), nc.copyHelp(ids, on: page)),
            help("Copy and paste", clip.pasteHelp(nil), nc.pasteHelp(nil)),
            help("Copy and paste", clip.pasteHelp(bytes), nc.pasteHelp(bytes)),
            help("Copy and paste", clip.pasteboardType, nc.pasteboardType),
            write("Copy and paste", { _ = try clip.encode(ids, on: page) }, { _ = try nc.encode(ids, on: page) }),
            write("Copy and paste", { _ = try clip.paste(bytes, into: nil, on: page, mint: &mint) },
                  { _ = try nc.paste(bytes, into: nil, on: page, mint: &mint) }),
            write("Style editing", { _ = try style.setFrame(.x, to: 300, ids, on: page) },
                  { _ = try ns.setFrame(.x, to: 300, ids, on: page) }),
            write("Style editing", { _ = try style.setFill(DesignColor(1, 2, 3), ids, on: page) },
                  { _ = try ns.setFill(DesignColor(1, 2, 3), ids, on: page) }),
            write("Style editing", { _ = try style.setCornerRadius(12, ids, on: page) },
                  { _ = try ns.setCornerRadius(12, ids, on: page) }),
            write("Style editing", { _ = try style.setOpacity(0.5, ids, on: page) }, { _ = try ns.setOpacity(0.5, ids, on: page) }),
            write("Style editing", { _ = try style.setStroke(nil, ids, on: page) }, { _ = try ns.setStroke(nil, ids, on: page) }),
            write("Style editing", { _ = try style.setTextStyle(.default, ids, on: page) },
                  { _ = try ns.setTextStyle(.default, ids, on: page) }),
        ]
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
        for property in [DesignStyleProperty.fill, .opacity] {
            rows.append(help("Style editing", style.styleHelp(property, ids, on: page), ns.styleHelp(property, ids, on: page)))
        }
        return rows
    }

    @Test(arguments: selections) func stubsAnswerAsNotBuilt(_ ids: [String]) {
        #expect(page.nodes.node("node-2")?.name == "A")
        let rows = answers(ids)
        #expect(rows.count > 20)
        for row in rows { #expect(row.stub == row.notBuilt, "\(row.name)") }
    }

    @Test(arguments: selections) func stubsRefuseWithTheirName(_ ids: [String]) {
        var mint = DesignIDMint(taken: [], after: 10)
        let refusals: [(DesignRefusal?, String)] = [
            (refusal { _ = try LiveDuplicating().duplicate(ids, offset: pt(10, 10), on: page, mint: &mint) }, "Duplicate"),
            (refusal { _ = try LiveGrouping().group(ids, on: page, mint: &mint) }, "Group"),
            (refusal { _ = try LiveClipboard().encode(ids, on: page) }, "Copy and paste"),
            (refusal { _ = try LiveOrdering().arrange(.bringForward, ids, on: page) }, "Reordering layers"),
            (refusal { _ = try LiveStyling().setFill(DesignColor(1, 2, 3), ids, on: page) }, "Style editing"),
        ]
        for (thrown, name) in refusals { #expect(thrown == .notBuilt(name)) }
        let helps: [(String?, String)] = [
            (LiveDuplicating().duplicateHelp(ids, on: page), "Duplicate"), (LiveGrouping().ungroupHelp(ids, on: page), "Group"),
            (LiveClipboard().copyHelp(ids, on: page), "Copy and paste"),
            (LiveOrdering().arrangeHelp(.sendBackward, ids, on: page), "Reordering layers"),
            (LiveStyling().styleHelp(.cornerRadius, ids, on: page), "Style editing"),
        ]
        for (help, name) in helps { #expect(help == "\(name) isn't built yet.") }
        #expect(mint.minted.isEmpty)
    }

    @Test func copySubtreeForwards() {
        var mint = DesignIDMint(taken: [], after: 10)
        let node = page.nodes.node("node-6") ?? DesignNode(id: "x", name: "x", kind: .group, frame: rc(0, 0, 1, 1))
        #expect(LiveDuplicating().copySubtree(node, mint: &mint) == node)
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
}
