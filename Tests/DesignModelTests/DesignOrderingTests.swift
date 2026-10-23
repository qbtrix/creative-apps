// DesignOrderingTests.swift: LiveOrdering, Move Layer and Object > Arrange over
// the kernel's layer tree (layers-panel L-1), on `cards`: Desktop holds A, B,
// C, Title, Pair (E1, E2), Locked and Hidden, back to front. Each refusal and
// its help, a move into a group, a reorder at the top level and inside a frame,
// index clamping, every arrange step on a multi-selection keeping its order,
// arrange per parent, `.unchanged` and its help, a lock through an ancestor,
// and the node round trip through the kernel. Runs on Linux and macOS.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignOrderingTests {
    let page = DesignFixtures.cards.selectedPage ?? DesignPage(id: "none", name: "None", frameWidth: 1, frameHeight: 1)
    let order = LiveOrdering()
    let desktop = "node-1", a = "node-2", b = "node-3", c = "node-4", title = "node-5"
    let pair = "node-6", e1 = "node-7", e2 = "node-8", locked = "node-9"

    /// The names of `parent`'s children (nil: the top level), back to front.
    private func names(_ nodes: [DesignNode], in parent: String?) -> [String] {
        (parent.map { nodes.node($0)?.children ?? [] } ?? nodes).map(\.name)
    }

    /// What `body` threw; nil when it returned.
    private func refusal(_ body: () throws(DesignRefusal) -> DesignEdit) -> DesignRefusal? {
        do { _ = try body() } catch { return error }
        return nil
    }

    /// `page` with `id` locked.
    private func locking(_ id: String) -> DesignPage {
        var locked = page
        _ = locked.nodes.update(id) { $0.isLocked = true }
        return locked
    }

    @Test func moveCountsTheParentsChildrenAfterRemoval() throws {
        let edit = try order.move(b, into: desktop, at: 2, on: page)
        #expect(names(edit.nodes, in: desktop) == ["A", "C", "B", "Title", "Pair", "Locked", "Hidden"])
        #expect(edit.name == "Move Layer" && edit.selection == [b] && edit.coalescingKey == nil)
    }

    @Test func moveNestsInAGroupAndClampsTheIndex() throws {
        let nested = try order.move(title, into: pair, at: 2, on: page)
        #expect(names(nested.nodes, in: pair) == ["E1", "E2", "Title"])
        #expect(!names(nested.nodes, in: desktop).contains("Title"))
        #expect(try order.move(title, into: pair, at: 99, on: page).nodes == nested.nodes)
        let first = try order.move(c, into: desktop, at: -5, on: page)
        #expect(names(first.nodes, in: desktop).prefix(2) == ["C", "A"])
    }

    @Test func moveReordersTheTopLevel() throws {
        let edit = try order.move(a, into: nil, at: 0, on: page)
        #expect(names(edit.nodes, in: nil) == ["A", "Desktop"])
        let back = try order.move(a, into: nil, at: 5, on: page)
        #expect(names(back.nodes, in: nil) == ["Desktop", "A"])
    }

    @Test func moveRefusals() {
        let cases: [(DesignRefusal?, DesignRefusal)] = [
            (refusal { () throws(DesignRefusal) in try order.move(a, into: e1, at: 0, on: page) }, .notAContainer("E1")),
            (refusal { () throws(DesignRefusal) in try order.move(pair, into: e2, at: 0, on: page) }, .intoItself("Pair")),
            (refusal { () throws(DesignRefusal) in try order.move(pair, into: pair, at: 0, on: page) }, .intoItself("Pair")),
            (refusal { () throws(DesignRefusal) in try order.move(desktop, into: e1, at: 0, on: page) }, .intoItself("Desktop")),
            (refusal { () throws(DesignRefusal) in try order.move(locked, into: nil, at: 0, on: page) }, .locked("Locked")),
            (refusal { () throws(DesignRefusal) in try order.move(a, into: locked, at: 0, on: locking(locked)) }, .notAContainer("Locked")),
            (refusal { () throws(DesignRefusal) in try order.move("nope", into: nil, at: 0, on: page) }, .unknownID("nope")),
            (refusal { () throws(DesignRefusal) in try order.move(a, into: "nope", at: 0, on: page) }, .unknownID("nope")),
            (refusal { () throws(DesignRefusal) in try order.move(a, into: desktop, at: 0, on: page) }, .unchanged),
        ]
        for (thrown, expected) in cases { #expect(thrown == expected) }
        #expect(order.moveHelp(a, into: e1, at: 0, on: page) == "E1 can't hold other layers.")
        #expect(order.moveHelp(pair, into: e2, at: 0, on: page) == "Pair can't go inside itself.")
        #expect(order.moveHelp(locked, into: nil, at: 0, on: page) == "Unlock Locked to change it.")
        #expect(order.moveHelp(a, into: desktop, at: 0, on: page) == "Nothing would change.")
        #expect(order.moveHelp(b, into: desktop, at: 2, on: page) == nil)
    }

    @Test func aLockThroughAnAncestorRefusesTheMoveAndTheTarget() {
        let lockedPair = locking(pair)
        #expect(refusal { () throws(DesignRefusal) in try order.move(e1, into: desktop, at: 0, on: lockedPair) } == .locked("Pair"))
        #expect(refusal { () throws(DesignRefusal) in try order.move(e1, into: pair, at: 1, on: lockedPair) } == .locked("Pair"))
        #expect(refusal { () throws(DesignRefusal) in try order.move(a, into: pair, at: 0, on: lockedPair) } == .locked("Pair"))
        #expect(refusal { () throws(DesignRefusal) in try order.arrange(.bringToFront, [e1], on: lockedPair) } == .locked("Pair"))
        let lockedDesktop = locking(desktop)
        #expect(order.moveHelp(e1, into: nil, at: 0, on: lockedDesktop) == "Unlock Desktop to change it.")
        #expect(order.arrangeHelp(.sendToBack, [a, b], on: lockedDesktop) == "Unlock Desktop to change it.")
    }

    @Test func eachArrangeStepKeepsTheSelectionsOrder() throws {
        let rest = ["Title", "Pair", "Locked", "Hidden"]
        let expected: [(DesignArrangeStep, [String], [String])] = [
            (.bringToFront, [a, b], ["C"] + rest + ["A", "B"]),
            (.bringForward, [a, b], ["C", "A", "B"] + rest),
            (.sendBackward, [c, b], ["B", "C", "A"] + rest),
            (.sendToBack, [c, b], ["B", "C", "A"] + rest),
        ]
        for (step, ids, arranged) in expected {
            let edit = try order.arrange(step, ids, on: page)
            #expect(names(edit.nodes, in: desktop) == arranged, "\(step)")
            #expect(edit.name == step.title && edit.selection == ids, "\(step)")
        }
    }

    @Test func forwardAndBackwardMoveOnePlace() throws {
        let forward = try order.arrange(.bringForward, [b], on: page)
        #expect(names(forward.nodes, in: desktop).prefix(3) == ["A", "C", "B"])
        let backward = try order.arrange(.sendBackward, [title], on: page)
        #expect(names(backward.nodes, in: desktop).prefix(4) == ["A", "B", "Title", "C"])
        let back = try order.arrange(.sendToBack, [b], on: page)
        #expect(names(back.nodes, in: desktop).first == "B")
        let front = try order.arrange(.bringToFront, [b, title], on: page)
        #expect(names(front.nodes, in: desktop).suffix(2) == ["B", "Title"])
    }

    @Test func arrangeWorksWithinEachLayersOwnParent() throws {
        let edit = try order.arrange(.bringToFront, [e1, a], on: page)
        #expect(names(edit.nodes, in: pair) == ["E2", "E1"])
        #expect(names(edit.nodes, in: desktop) == ["B", "C", "Title", "Pair", "Locked", "Hidden", "A"])
        let back = try order.arrange(.sendToBack, [e2, c], on: page)
        #expect(names(back.nodes, in: pair) == ["E2", "E1"])
        #expect(names(back.nodes, in: desktop).first == "C")
    }

    @Test func anArrangeThatChangesNothingSaysSo() {
        #expect(refusal { () throws(DesignRefusal) in try order.arrange(.sendToBack, [a], on: page) } == .unchanged)
        #expect(order.arrangeHelp(.sendToBack, [a], on: page) == "Nothing would change.")
        #expect(order.arrangeHelp(.sendBackward, [a, b], on: page) == "Nothing would change.")
        #expect(order.arrangeHelp(.bringToFront, [desktop], on: page) == "Nothing would change.")
        #expect(order.arrangeHelp(.bringToFront, [a], on: page) == nil)
        #expect(order.arrangeHelp(.bringForward, [], on: page) == DesignRefusal.nothingSelected.help)
        #expect(order.arrangeHelp(.bringForward, [locked], on: page) == "Unlock Locked to change it.")
        #expect(refusal { () throws(DesignRefusal) in try order.arrange(.bringForward, [a, "nope"], on: page) } == .unknownID("nope"))
    }

    @Test func nodesRoundTripThroughTheKernelTree() {
        #expect(page.nodes.layerTree.designNodes == page.nodes)
        #expect(page.nodes.layerTree.node(pair)?.payload.holdsChildren == true)
        #expect(page.nodes.layerTree.node(e1)?.payload.holdsChildren == false)
        #expect(page.nodes.layerTree.isEffectivelyLocked(locked))
        #expect(DesignArrangeStep.allCases.map(\.kernelStep) == [.bringToFront, .bringForward, .sendBackward, .sendToBack])
    }

    @Test func liveObeysTheHelpLaw() {
        let law = DesignContractLaw.check(.live, on: page)
        #expect(law.violations.isEmpty, "\(law.violations)")
    }
}
