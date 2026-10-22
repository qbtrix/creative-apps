// ShellFontListTests.swift: shell-text ST-5 (MJ-ST3, packet
// suite/features/shell-text.md). FontCatalog lists the Mac's families, each
// with its faces: the system UI family (FakeText's "System UI" name, the one
// CoreTextMeasurer resolves an empty family to) with at least a regular and a
// bold face, Helvetica with its regular and bold, every family once, sorted by
// name, every face once with a weight in hundreds from 100 to 900. A listed
// face measures in its own family. macOS only.
#if os(macOS)
import SuiteModel
import SuiteShell
import Testing

@Suite(.timeLimit(.minutes(1))) struct ShellFontListTests {
    let families = FontCatalog().families()

    private func family(_ name: String) throws -> FontFamily {
        try #require(families.first { $0.name == name }, "\(name) isn't listed")
    }

    @Test func systemFamilyHasRegularAndBold() throws {
        let system = try family(FakeText.systemFamily)
        #expect(system.faces.contains { $0.weight == 400 && !$0.italic })
        #expect(system.faces.contains { $0.weight == 700 && !$0.italic })
    }

    @Test func helveticaHasRegularAndBold() throws {
        let helvetica = try family("Helvetica")
        #expect(helvetica.faces.contains { $0.weight == 400 && !$0.italic })
        #expect(helvetica.faces.contains { $0.weight == 700 && !$0.italic })
    }

    @Test func familiesAreSortedAndUnique() {
        #expect(families.count > 10)
        let names = families.map(\.name)
        #expect(Set(names).count == names.count)
        #expect(names == names.sorted { FontCatalog.ordered($0, $1) })
        #expect(!names.contains { $0.hasPrefix(".") })
    }

    @Test func facesAreUniqueWithWeightsInHundreds() {
        for family in families {
            #expect(!family.faces.isEmpty, "\(family.name) has no faces")
            #expect(Set(family.faces.map(\.name)).count == family.faces.count, "\(family.name) repeats a face")
            #expect(family.faces.allSatisfy { (100...900).contains($0.weight) && $0.weight % 100 == 0 })
        }
    }

    @Test func aListedFaceMeasuresInItsFamily() throws {
        let helvetica = try family("Helvetica")
        let bold = try #require(helvetica.faces.first { $0.weight == 700 && !$0.italic })
        let span = TextSpan("Hello", fontFamily: helvetica.name, fontSize: 20, weight: bold.weight, italic: bold.italic)
        let metrics = try CoreTextMeasurer().measure([span])
        #expect(metrics.first?.resolvedFamily == "Helvetica")
    }
}
#endif
