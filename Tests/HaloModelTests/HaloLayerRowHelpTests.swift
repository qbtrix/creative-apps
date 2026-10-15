// HaloLayerRowHelpTests.swift: a layer row's tooltip names the kind first,
// then tells a newcomer the row renames on a double-click and reorders by
// drag; a null's also says it draws nothing.
import HaloModel
import Testing

@Suite struct HaloLayerRowHelpTests {
    @Test(arguments: HaloLayerKind.allCases)
    func rowHelpNamesTheKindAndTheGestures(kind: HaloLayerKind) {
        #expect(kind.rowHelp.hasPrefix(kind.layerTitle))
        #expect(kind.rowHelp.contains("Double-click"))
        #expect(kind.rowHelp.contains("drag"))
    }

    @Test func nullRowHelpSaysItDrawsNothing() {
        #expect(HaloLayerKind.null.rowHelp.contains("draws nothing"))
        #expect(!HaloLayerKind.shape.rowHelp.contains("draws nothing"))
    }

    @Test func rowHelpsAreDistinct() {
        #expect(Set(HaloLayerKind.allCases.map(\.rowHelp)).count == HaloLayerKind.allCases.count)
    }
}
