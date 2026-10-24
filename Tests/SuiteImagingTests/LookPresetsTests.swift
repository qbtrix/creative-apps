// LookPresetsTests.swift (adjust-everywhere AJ-2): the six built-in looks
// exist as data, in grid order, and each one encodes and decodes to itself, so
// every look the grid lists has values a store can keep.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
import SuiteImaging

@Suite struct LookPresetsTests {
    @Test func sixBuiltInsInGridOrder() {
        #expect(BuiltInLooks.all.map(\.id) == ["bw", "bw-high-contrast", "warm", "cool", "fade", "vivid"])
        #expect(BuiltInLooks.all.allSatisfy { $0.builtIn && !$0.name.isEmpty })
        #expect(Set(BuiltInLooks.all.map(\.name)).count == 6)
        #expect(BuiltInLooks.look("fade")?.name == "Fade" && BuiltInLooks.look("sepia") == nil)
    }

    /// Each look changes the picture: the black-and-white ones carry the kind, the rest tone or adjust.
    @Test func everyLookHasData() {
        for look in BuiltInLooks.all {
            #expect(!look.kinds.isEmpty || look.tone != .neutral || look.adjust != .neutral, "\(look.id)")
        }
        #expect(BuiltInLooks.look("bw")?.kinds == [.blackAndWhite(.neutral)])
        #expect(BuiltInLooks.look("warm")?.tone.value(.temperature) ?? 0 > 0)
        #expect(BuiltInLooks.look("cool")?.tone.value(.temperature) ?? 0 < 0)
    }

    @Test func builtInsDecode() throws {
        for look in BuiltInLooks.all {
            let data = try JSONEncoder().encode(look)
            #expect(try JSONDecoder().decode(LookPreset.self, from: data) == look, "\(look.id)")
        }
    }
}
