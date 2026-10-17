// UniqueFileNamesTests.swift: the one unique-file-name rule, case by case
// (docs/blueprints/design/features/design-export.md, DE-0's acceptance row).
import SuiteModel
import Testing

@Suite struct UniqueFileNamesTests {
    @Test func freeNameIsUsedAsIs() {
        #expect(UniqueFileNames.name("Card", extension: "png", among: []) == "Card.png")
    }

    @Test func takenNameGetsSuffixTwoFirst() {
        #expect(UniqueFileNames.name("Card", extension: "png", among: ["Card.png"]) == "Card 2.png")
    }

    @Test func suffixCountsPastTakenOnes() {
        #expect(UniqueFileNames.name("Card", extension: "png", among: ["Card.png", "Card 2.png"]) == "Card 3.png")
    }

    @Test func comparisonIgnoresCase() {
        #expect(UniqueFileNames.name("Card", extension: "png", among: ["card.png"]) == "Card 2.png")
    }

    @Test func takenSuffixInAnotherCaseIsSkipped() {
        #expect(UniqueFileNames.name("Card", extension: "png", among: ["card.png", "CARD 2.png"]) == "Card 3.png")
    }

    @Test func slashAndColonBecomeDashes() {
        #expect(UniqueFileNames.name("A/B:C", extension: "png", among: []) == "A-B-C.png")
    }

    @Test func emptyBaseIsUntitled() {
        #expect(UniqueFileNames.name("", extension: "png", among: []) == "Untitled.png")
    }

    @Test func whitespaceOnlyBaseIsUntitled() {
        #expect(UniqueFileNames.name("  \t", extension: "png", among: []) == "Untitled.png")
    }

    @Test func emptyExtensionHasNoDot() {
        #expect(UniqueFileNames.name("Card", extension: "", among: []) == "Card")
        #expect(UniqueFileNames.name("Card", extension: "", among: ["card"]) == "Card 2")
    }
}
