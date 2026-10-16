// SuiteWindowSizeTests.swift: the `-SuiteWindowSize WxH` parser SuiteWindow
// reads at launch (SuiteWindowSizer.swift). A good value gives its size, a
// malformed, zero or missing one gives nil, and the flag is found among other
// launch arguments. macOS only.
import SuiteUI
import SwiftUI
import Testing

@Suite struct SuiteWindowSizeTests {
    @Test func theFlagGivesItsSize() {
        #expect(SuiteWindowSize.parse(["-SuiteWindowSize", "1024x768"]) == CGSize(width: 1024, height: 768))
    }

    @Test func aBadValueGivesNil() {
        for bad in ["1024", "x768", "1024x", "0x0", "0x768", "1024x0", "-1024x768", "axb", "1024x768x2", ""] {
            #expect(SuiteWindowSize.parse(["-SuiteWindowSize", bad]) == nil, "\(bad)")
        }
    }

    @Test func aMissingValueOrFlagGivesNil() {
        #expect(SuiteWindowSize.parse(["-SuiteWindowSize"]) == nil)
        #expect(SuiteWindowSize.parse(["LibraryApp"]) == nil)
        #expect(SuiteWindowSize.parse([]) == nil)
    }

    @Test func theFlagIsFoundAmongOtherArguments() {
        let arguments = ["LibraryApp", "-SuiteGallery", "editor-window", "-SuiteWindowSize", "1024x768", "-AppleLanguages", "(en)"]
        #expect(SuiteWindowSize.parse(arguments) == CGSize(width: 1024, height: 768))
    }
}
