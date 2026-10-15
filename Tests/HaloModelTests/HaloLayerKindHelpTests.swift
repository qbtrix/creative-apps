// HaloLayerKindHelpTests.swift: every layer kind names itself for the layer
// row's tooltip and VoiceOver value ("Solid layer", "Null layer"), from the
// same title the menus show, and no two kinds share a name.
import HaloModel
import Testing

@Suite struct HaloLayerKindHelpTests {
    @Test(arguments: HaloLayerKind.allCases)
    func layerTitleNamesTheKind(kind: HaloLayerKind) {
        #expect(!kind.title.isEmpty)
        #expect(kind.layerTitle == "\(kind.title) layer")
    }

    @Test func layerTitlesAreDistinctAndReadable() {
        #expect(HaloLayerKind.solid.layerTitle == "Solid layer")
        #expect(HaloLayerKind.null.layerTitle == "Null layer")
        #expect(Set(HaloLayerKind.allCases.map(\.layerTitle)).count == HaloLayerKind.allCases.count)
    }
}
