// SuiteHelpWindowTests.swift: where Help > Beta Notes's window opens. It has
// to sit centred on the screen at its full size, so Close stays on a 1024 x
// 768 runner (#4760: Close at x 988-1047, off the right edge, though the
// window was centred before its content sized it). macOS only.
#if canImport(AppKit)
import AppKit
import Testing

@testable import SuiteShell

@MainActor @Suite struct SuiteHelpWindowTests {
    @Test func betaNotesOpenCentredAtItsFullSize() throws {
        let presenter = SuiteHelpPresenter()
        presenter.showBetaNotes()
        let window = try #require(NSApp.windows.first { $0.title == "Beta Notes" && $0.isVisible })
        defer { window.close() }
        let screen = try #require(window.screen ?? NSScreen.main).visibleFrame
        #expect(window.frame.width >= 400, "the window is \(window.frame.width) pt wide, not its content's width")
        #expect(abs(window.frame.midX - screen.midX) <= 1, "the window \(window.frame) isn't centred on \(screen)")
        #expect(screen.contains(window.frame), "the window \(window.frame) runs off \(screen)")
    }
}
#endif
