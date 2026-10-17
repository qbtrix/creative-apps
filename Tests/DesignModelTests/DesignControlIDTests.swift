// DesignControlIDTests.swift: design-window D0-7a. Every id in
// DesignControlID.all is unique and reads `design.<area>.<name>` (lowercase,
// dot-separated, three parts or more), and the list holds the ids the window
// and its views register: the canvas, its selection, every toolbar item (Undo
// is `design.bar.undo`), every palette tool, the status line, and each Align
// and Distribute button. Linux.
import DesignModel
import Testing

@Suite struct DesignControlIDTests {
    /// `design.<area>.<name>`: lowercase letters, digits and hyphens between the dots.
    static func isWellFormed(_ id: String) -> Bool {
        let parts = id.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts.first == "design" else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.first != "-" && part.last != "-"
                && part.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-" }
        }
    }

    @Test func everyIDIsUnique() {
        let all = DesignControlID.all
        #expect(Set(all).count == all.count, "repeated: \(all.filter { id in all.filter { $0 == id }.count > 1 })")
    }

    @Test func everyIDReadsDesignAreaName() {
        for id in DesignControlID.all {
            #expect(Self.isWellFormed(id), "\(id) is not design.<area>.<name>")
        }
    }

    @Test func theShapeCheckRefusesBadIDs() {
        #expect(Self.isWellFormed("design.canvas.selection"))
        #expect(Self.isWellFormed("design.bar.zoom-in"))
        #expect(!Self.isWellFormed("design.new-file"))
        #expect(!Self.isWellFormed("design.Canvas.page"))
        #expect(!Self.isWellFormed("photo.canvas.page"))
        #expect(!Self.isWellFormed("design..page"))
    }

    @Test func theListHoldsTheWindowsOwnControls() {
        let all = Set(DesignControlID.all)
        #expect(all.contains("design.canvas.selection"))
        #expect(all.contains("design.bar.undo"))
        #expect(all.contains(DesignControlID.canvas))
        #expect(all.contains(DesignControlID.statusTool))
        #expect(all.contains(DesignControlID.statusSelection))
        #expect(all.contains(DesignControlID.statusNote))
        for item in DesignToolbarItem.allCases {
            #expect(all.contains(item.identifier), "toolbar \(item) is unlisted")
        }
        for tool in DesignTool.allCases {
            #expect(all.contains(DesignControlID.tool(tool)), "tool \(tool) is unlisted")
        }
    }

    @Test func theListHoldsEachAlignAndDistributeButton() {
        let all = Set(DesignControlID.all)
        for edge in DesignAlignEdge.allCases {
            #expect(all.contains(DesignControlID.align(edge)), "Align \(edge) is unlisted")
        }
        for axis in DesignDistributeAxis.allCases {
            #expect(all.contains(DesignControlID.distribute(axis)), "Distribute \(axis) is unlisted")
        }
        #expect(DesignControlID.align(.left) == "design.align.left")
        #expect(DesignControlID.distribute(.vertical) == "design.distribute.vertical")
        #expect(DesignControlID.tool(.rectangle) == "design.tool.rectangle")
    }
}
