// PhotoRecentMenuTests.swift: File > Open Recent with and without a window.
// A focused window's list wins and picks go to it; with no window (after the
// last one closed) the saved list shows and picks open a new window, so Open
// Recent > beach.ora still works (PJ-1/PJ-2). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import PhotoModel
import Testing

@Suite struct PhotoRecentMenuTests {
    let beach = URL(fileURLWithPath: "/tmp/beach.ora")
    let dune = URL(fileURLWithPath: "/tmp/dune.png")

    @Test func aFocusedWindowsListShowsAndTakesThePick() {
        let menu = PhotoRecentMenu(focused: [dune], stored: [beach, dune])
        #expect(menu.files == [dune])
        #expect(menu.target == .focusedWindow)
        #expect(menu.canClear)
    }

    @Test func withNoWindowTheSavedListShowsAndAPickOpensANewWindow() {
        let menu = PhotoRecentMenu(focused: nil, stored: [beach, dune])
        #expect(menu.files == [beach, dune])
        #expect(menu.target == .noWindow)
        #expect(menu.canClear)
    }

    @Test func aFocusedWindowWithAnEmptyListStaysEmpty() {
        let menu = PhotoRecentMenu(focused: [], stored: [beach])
        #expect(menu.files.isEmpty)
        #expect(menu.target == .focusedWindow)
        #expect(!menu.canClear)
    }

    @Test func noWindowAndNothingSavedDisablesClearMenu() {
        let menu = PhotoRecentMenu(focused: nil, stored: [])
        #expect(menu.files.isEmpty)
        #expect(menu.target == .noWindow)
        #expect(!menu.canClear)
    }
}
