// DesignKernelSelectionAdapterTests.swift: the Design workspace's selection is
// SuiteKernel's `Selection<String>` (adopt-kernel-selection AS-design). The
// ordered ids and the primary are the kernel's; a change ends the edit run and a
// refused Shift-click changes nothing; Select All and a marquee go through the
// kernel's selectAll and Marquee.union, so a marquee replaces the selection;
// Nudge.delta sizes the step.
// Plan: Tests/mutations/DesignModel.KernelSelectionAdapter.json. Runs on Linux
// and macOS.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignKernelSelectionAdapterTests {
    /// `cards` on the fake services: Desktop node-1 holds A node-2, B node-3, C node-4, Title
    /// node-5, Pair node-6, Locked node-9 and Hidden node-10.
    static func cards() -> DesignWorkspace {
        var workspace = DesignFixtures.cards
        workspace.useServices(.fake)
        return workspace
    }

    @Test func theSelectionIsTheKernelsInPickOrder() {
        var workspace = Self.cards()
        workspace.selectItem("node-3")
        workspace.toggleSelection("node-2")
        #expect(workspace.selection.ordered == ["node-3", "node-2"])
        #expect(workspace.selectedNodeIDs == workspace.selection.ordered)
        #expect(workspace.selection.primary == "node-2")
        #expect(workspace.selectedNodeID == "node-2")
        workspace.toggleSelection("node-2")
        #expect(workspace.selection.ordered == ["node-3"])
        #expect(workspace.selectedNodeID == "node-3")
        #expect(workspace.selection.anchor == "node-3")
    }

    @Test func aRefusedShiftClickChangesNothingAndKeepsTheRun() {
        var workspace = Self.cards()
        workspace.selectItem("node-2")
        workspace.nudge(.right, shift: false)
        for refused in ["node-9", "node-10"] {
            let before = workspace
            workspace.toggleSelection(refused)
            #expect(workspace.selectedNodeIDs == ["node-2"])
            #expect(workspace == before)
        }
        workspace.nudge(.right, shift: false)
        #expect(workspace.history.undo.count == 1)
    }

    @Test func aShiftClickThatAddsEndsTheRun() {
        var workspace = Self.cards()
        workspace.selectItem("node-2")
        workspace.nudge(.right, shift: false)
        workspace.toggleSelection("node-3")
        workspace.toggleSelection("node-3")
        workspace.nudge(.right, shift: false)
        #expect(workspace.history.undo.count == 2)
    }

    @Test func selectAllTakesOnlyLayersTheKernelMayAdd() {
        var workspace = Self.cards()
        workspace.selectItem("node-2")
        workspace.selectAll()
        #expect(!workspace.selectedNodeIDs.isEmpty)
        #expect(!workspace.selectedNodeIDs.contains("node-9"))
        #expect(!workspace.selectedNodeIDs.contains("node-10"))
        #expect(workspace.selection.primary == workspace.selectedNodeIDs.last)
    }

    @Test func aMarqueeReplacesTheSelectionItStartsFrom() {
        var workspace = Self.cards()
        workspace.selectItem("node-4")
        workspace.drag(from: pt(80, 80), to: pt(520, 240))
        #expect(workspace.marquee == rc(80, 80, 440, 160))
        #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
        workspace.endDrag()
        #expect(workspace.selection.ordered == ["node-2", "node-3"])
    }

    @Test func aMarqueeDraggedUpAndLeftEnclosesBothCorners() {
        var workspace = Self.cards()
        workspace.drag(from: pt(520, 240), to: pt(80, 80))
        #expect(workspace.marquee == rc(80, 80, 440, 160))
    }

    @Test func shiftNudgeIsTheKernelsLargeStepAndUpIsNegative() throws {
        var workspace = Self.cards()
        workspace.selectItem("node-2")
        let start = try #require(workspace.frame("node-2"))
        workspace.nudge(.left, shift: true)
        workspace.nudge(.up, shift: false)
        let end = try #require(workspace.frame("node-2"))
        #expect(end.x == start.x - 10)
        #expect(end.y == start.y - 1)
    }
}
