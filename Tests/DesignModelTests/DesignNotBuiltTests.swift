// DesignNotBuiltTests.swift: DesignServices.live before any feature lands. Every
// slot is NotBuilt with blueprint 5.6's feature name; each help says "<Feature>
// isn't built yet." and each write throws `.notBuilt(feature)`, on DesignFixtures'
// `cards` with A selected. Also the workspace's services: useServices keeps the
// document, and a workspace's equality sees which services it runs on. Runs on
// Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

@Suite struct DesignNotBuiltTests {
    let page = DesignFixtures.cards.selectedPage ?? DesignPage(id: "none", name: "None", frameWidth: 1, frameHeight: 1)
    let ids = ["node-2"]  // A
    let live = DesignServices.live

    /// The feature a slot's NotBuilt names; nil when the slot is something else.
    private func feature(_ slot: Any) -> String? { (slot as? NotBuilt)?.feature }

    /// What `body` threw as a refusal; nil when it returned (or threw something else).
    private func refusal(_ body: () throws -> Void) -> DesignRefusal? {
        do { try body() } catch { return error as? DesignRefusal }
        return nil
    }

    @Test func everySlotNamesItsFeature() {
        let slots: [(Any, String)] = [
            (live.marquee, "Marquee selection"), (live.transforming, "Editing several layers"),
            (live.aligning, "Aligning several layers"), (live.duplicating, "Duplicate"), (live.grouping, "Group"),
            (live.clipboard, "Copy and paste"), (live.ordering, "Reordering layers"), (live.styling, "Style editing"),
            (live.framing, "Zoom to Selection"), (live.filing, "Saving"), (live.export, "Export"),
            (live.pen, "The Pen tool"), (live.components, "Components"), (live.variables, "Variables"),
        ]
        for (slot, name) in slots { #expect(feature(slot) == name) }
        #expect(live.name == "live")
    }

    @Test func everyHelpSaysItIsNotBuilt() {
        #expect(page.nodes.node("node-2")?.name == "A")
        let helps: [(String?, String)] = [
            (live.transforming.transformHelp(ids, on: page), "Editing several layers"),
            (live.aligning.alignHelp(.top, ids, on: page), "Aligning several layers"),
            (live.aligning.distributeHelp(.horizontal, ids, on: page), "Aligning several layers"),
            (live.duplicating.duplicateHelp(ids, on: page), "Duplicate"),
            (live.grouping.groupHelp(ids, on: page), "Group"),
            (live.grouping.ungroupHelp(ids, on: page), "Group"),
            (live.clipboard.copyHelp(ids, on: page), "Copy and paste"),
            (live.clipboard.pasteHelp(nil), "Copy and paste"),
            (live.ordering.moveHelp("node-2", into: nil, at: 0, on: page), "Reordering layers"),
            (live.ordering.arrangeHelp(.bringToFront, ids, on: page), "Reordering layers"),
            (live.styling.styleHelp(.fill, ids, on: page), "Style editing"),
            (live.framing.framingHelp(ids, on: page), "Zoom to Selection"),
            (live.export.exportHelp(ids, on: page), "Export"),
            (live.components.createHelp(ids, on: page), "Components"),
        ]
        for (help, name) in helps { #expect(help == "\(name) isn't built yet.") }
    }

    @Test func everyWriteThrowsNotBuilt() {
        var mint = DesignIDMint(taken: [], after: 10)
        let move = pt(10, 0)
        let path = DesignPath(anchors: [DesignAnchor(point: pt(0, 0)), DesignAnchor(point: pt(10, 10))], isClosed: false)
        let writes: [(DesignRefusal?, String)] = [
            (refusal { _ = try live.transforming.move(ids, by: move, on: page) }, "Editing several layers"),
            (refusal { _ = try live.transforming.resize(ids, handle: .right, by: move, modifiers: [], on: page) }, "Editing several layers"),
            (refusal { _ = try live.transforming.nudge(ids, .left, large: false, on: page) }, "Editing several layers"),
            (refusal { _ = try live.transforming.delete(ids, on: page) }, "Editing several layers"),
            (refusal { _ = try live.aligning.align(.top, ids, on: page) }, "Aligning several layers"),
            (refusal { _ = try live.aligning.distribute(.vertical, ids, on: page) }, "Aligning several layers"),
            (refusal { _ = try live.duplicating.duplicate(ids, offset: move, on: page, mint: &mint) }, "Duplicate"),
            (refusal { _ = try live.grouping.group(ids, on: page, mint: &mint) }, "Group"),
            (refusal { _ = try live.grouping.ungroup(ids, on: page) }, "Group"),
            (refusal { _ = try live.clipboard.encode(ids, on: page) }, "Copy and paste"),
            (refusal { _ = try live.clipboard.paste(Data(), into: nil, on: page, mint: &mint) }, "Copy and paste"),
            (refusal { _ = try live.ordering.move("node-2", into: nil, at: 0, on: page) }, "Reordering layers"),
            (refusal { _ = try live.ordering.arrange(.sendToBack, ids, on: page) }, "Reordering layers"),
            (refusal { _ = try live.styling.setFrame(.x, to: 5, ids, on: page) }, "Style editing"),
            (refusal { _ = try live.styling.setFill(DesignColor(1, 2, 3), ids, on: page) }, "Style editing"),
            (refusal { _ = try live.styling.setCornerRadius(4, ids, on: page) }, "Style editing"),
            (refusal { _ = try live.styling.setOpacity(0.5, ids, on: page) }, "Style editing"),
            (refusal { _ = try live.styling.setStroke(nil, ids, on: page) }, "Style editing"),
            (refusal { _ = try live.styling.setTextStyle(.default, ids, on: page) }, "Style editing"),
            (refusal { _ = try live.export.plan(ids, on: page, format: .svg, scale: 1, existing: []) }, "Export"),
            (refusal { _ = try live.export.svg(for: "node-2", on: page) }, "Export"),
            (refusal { _ = try live.pen.commit(path, into: nil, on: page, mint: &mint) }, "The Pen tool"),
            (refusal { _ = try live.components.create(from: "node-1", on: page, library: [], mint: &mint) }, "Components"),
            (refusal { _ = try live.components.insert("c", centeredOn: move, on: page, library: [], mint: &mint) }, "Components"),
            (refusal { _ = try live.variables.add(named: "Ink", value: .number(1), to: [], id: "v") }, "Variables"),
            (refusal { _ = try live.variables.rename("v", to: "Ink", in: []) }, "Variables"),
            (refusal { _ = try live.variables.remove("v", from: []) }, "Variables"),
            (refusal { _ = try live.variables.set("v", .dark, to: .number(2), in: []) }, "Variables"),
            (refusal { _ = try live.variables.bind("v", ids, on: page, variables: []) }, "Variables"),
        ]
        for (thrown, name) in writes { #expect(thrown == .notBuilt(name)) }
        #expect(mint.minted.isEmpty)
    }

    @Test func readsAnswerNothing() {
        #expect(live.marquee.layers(touching: rc(80, 80, 440, 160), in: "node-1", on: page) == [])
        #expect(live.framing.rectToShow(ids, on: page) == nil)
        #expect(live.pen.bounds(of: DesignPath(anchors: [DesignAnchor(point: pt(0, 0))], isClosed: false)) == nil)
        #expect(live.variables.resolve("v", in: .light, variables: []) == nil)
    }

    @Test func filingRefusesBothWays() {
        let decode: DesignFileError?
        do { _ = try live.filing.decode(Data("{}".utf8)); decode = nil } catch { decode = error }
        #expect(decode == .unreadable)
        let encode: DesignFileError?
        do { _ = try live.filing.encode(DesignDocument(pages: [page])); encode = nil } catch { encode = error }
        #expect(encode == .noFile)
    }

    @Test func useServicesKeepsTheDocument() {
        var workspace = DesignFixtures.cards
        workspace.selectItem("node-2")
        let before = workspace
        workspace.useServices(.live)
        #expect(workspace == before)
        #expect(workspace.pages == before.pages)
        #expect(workspace.selectedNodeIDs == ["node-2"])
        #expect(workspace.services.name == "live")
    }

    @Test func servicesTakePartInWorkspaceEquality() {
        let built = DesignServices(
            name: "test", marquee: NotBuilt("Marquee selection"), transforming: NotBuilt("Editing several layers"),
            aligning: NotBuilt("Aligning several layers"), duplicating: NotBuilt("Duplicate"), grouping: NotBuilt("Group"),
            clipboard: NotBuilt("Copy and paste"), ordering: NotBuilt("Reordering layers"), styling: NotBuilt("Style editing"),
            framing: NotBuilt("Zoom to Selection"), filing: NotBuilt("Saving"), export: NotBuilt("Export"),
            pen: NotBuilt("The Pen tool"), components: NotBuilt("Components"), variables: NotBuilt("Variables"))
        let onLive = DesignFixtures.cards
        var onTest = onLive
        onTest.useServices(built)
        #expect(onLive.services.name == "live")
        #expect(onLive == onLive)
        #expect(onTest == onTest)
        #expect(onLive != onTest)
        #expect(built != .live)
        onTest.useServices(.live)
        #expect(onTest == onLive)
    }
}
