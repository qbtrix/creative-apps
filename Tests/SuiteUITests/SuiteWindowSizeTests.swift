// SuiteWindowSizeTests.swift: the `-SuiteWindowSize WxH` parser SuiteWindow
// reads at launch (SuiteWindowSizer.swift). A good value gives its size, a
// malformed, zero or missing one gives nil, and the flag is found among other
// launch arguments. `fitted(_:in:)`, the math the sizer applies at launch and
// again when the visible frame moves (#1778): a launch size taller than the
// display's visible frame comes out that frame's height at its top, a frame
// that fits is unchanged, one past an edge moves inside, and an empty or
// non-finite visible frame changes nothing. macOS only.
import SuiteUI
import SwiftUI
import Testing

@Suite struct SuiteWindowSizeTests {
    /// The runner's 1024 x 768 display with its menu bar and Dock taken out, in points from the top left.
    static let visible = CGRect(x: 0, y: 31, width: 1024, height: 674)

    @Test func aLaunchSizeTallerThanTheVisibleFrameFillsItsHeight() {
        let requested = CGRect(x: 0, y: 31, width: 1024, height: 768)
        #expect(SuiteWindowSize.fitted(requested, in: Self.visible) == Self.visible)
        // Wider too: both sides clamp, and the frame still starts at the visible frame's corner.
        let huge = CGRect(x: 0, y: 31, width: 1400, height: 900)
        #expect(SuiteWindowSize.fitted(huge, in: Self.visible) == Self.visible)
    }

    @Test func aFrameThatFitsIsUnchanged() {
        let frame = CGRect(x: 100, y: 100, width: 800, height: 500)
        #expect(SuiteWindowSize.fitted(frame, in: Self.visible) == frame)
        #expect(SuiteWindowSize.fitted(Self.visible, in: Self.visible) == Self.visible)
    }

    @Test func aFrameHangingPastAnEdgeMovesInside() {
        // 3 pt below the visible frame's bottom (the window #1778 measured): up by 3, same size.
        let low = CGRect(x: 0, y: 34, width: 1024, height: 674)
        #expect(SuiteWindowSize.fitted(low, in: Self.visible) == Self.visible)
        let pastTheCorner = CGRect(x: 300, y: 0, width: 800, height: 600)
        #expect(SuiteWindowSize.fitted(pastTheCorner, in: Self.visible) == CGRect(x: 224, y: 31, width: 800, height: 600))
    }

    @Test func anEmptyOrNonFiniteVisibleFrameLeavesTheFrameAlone() {
        let frame = CGRect(x: 0, y: 31, width: 1024, height: 768)
        for visible in [
            CGRect.zero, CGRect(x: 0, y: 0, width: 1024, height: 0), CGRect(x: 0, y: 0, width: 0, height: 768),
            CGRect(x: 0, y: 0, width: .infinity, height: 768), CGRect(x: .nan, y: 0, width: 1024, height: 768),
        ] {
            #expect(SuiteWindowSize.fitted(frame, in: visible) == frame, "\(visible)")
        }
    }

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
