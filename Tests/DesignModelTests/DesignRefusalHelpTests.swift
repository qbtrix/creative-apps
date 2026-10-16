// DesignRefusalHelpTests.swift: every DesignRefusal's `help` is the sentence
// blueprint 5.2 gives it (the tooltip a disabled control shows), and
// DesignEdit.runKey sorts its ids so a run's key never depends on selection
// order. Runs on Linux and macOS.
import DesignModel
import Testing

@Suite struct DesignRefusalHelpTests {
    /// Every case, with the sentence blueprint 5.2 gives it.
    private static let sentences: [(DesignRefusal, String)] = [
        (.nothingSelected, "Select a layer first."),
        (.locked("Card"), "Unlock Card to change it."),
        (.hidden("Card"), "Show Card to change it."),
        (.notSameParent, "Select layers that share a parent."),
        (.tooFew(needed: 2), "Select two or more layers."),
        (.tooFew(needed: 3), "Select 3 or more layers."),
        (.notAGroup("Card"), "Card isn't a group."),
        (.notAContainer("Card"), "Card can't hold other layers."),
        (.intoItself("Card"), "Card can't go inside itself."),
        (.notAFrame("Card"), "Card isn't a frame."),
        (.noCorners("Title"), "Title has no corners to round."),
        (.notText("Card"), "Card isn't a text layer."),
        (.tooFewToDistribute, "Select three or more layers to distribute."),
        (.nothingToExport, "There's nothing on this page to export."),
        (.emptyName, "A name can't be empty."),
        (.nameTaken("Primary"), "Primary is already used."),
        (.unknownID("node-9"), "node-9 isn't on this page."),
        (.unreadable, "The pasteboard holds no Design layers."),
        (.unchanged, "Nothing would change."),
        (.notBuilt("Duplicate"), "Duplicate isn't built yet."),
    ]

    @Test func everyCaseReadsTheBlueprintSentence() {
        for (refusal, sentence) in Self.sentences {
            #expect(refusal.help == sentence)
        }
    }

    @Test func tooFewTwoReadsInWords() {
        #expect(DesignRefusal.tooFew(needed: 2).help == "Select two or more layers.")
    }

    @Test func runKeyIsIndependentOfOrder() {
        #expect(DesignEdit.runKey("move", ["node-4", "node-3"]) == "move-node-3,node-4")
        #expect(DesignEdit.runKey("move", ["node-3", "node-4"]) == "move-node-3,node-4")
    }
}
