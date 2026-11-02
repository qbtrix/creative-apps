// RenderBudgetHistoryPanelTests.swift (autosave-history AH-4, the packet's two render quality rows): HistoryPanel
// over "Open" and fifty undone steps in a real 1280 x 820 window, hosted the way the gallery's `history-panel` page
// hosts it, under a window that counts its own bodies. Fifty Down presses at 120 Hz walk the selection from "Open" to
// step 50 without a jump, and 120 pointer samples hover down the rows without one: each in at most 3 window bodies
// (target 0: only the panel and the rows whose state changed redraw). The p95s (packet: <= 8 ms) are printed, not
// gated: a step-time budget belongs in a Tests/perf-suites.txt test. Keys need a key window, so the walk builds the
// harness's key-capable one (never an isa swizzle, RenderBudgetHarness), focuses the panel by a click on "Open"
// (which jumps nowhere: "Open" is current), and sends the presses through the window as AppKit sends a hand's.
// Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHistoryPanelTests {
        static let steps = 50

        @Test(.timeLimit(.minutes(2))) func arrowWalkInThreeBodies() async throws {
            let w = RenderBudgetWindow(HistoryPanelBudgetWindow(), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            _ = w.window.makeFirstResponder(w.host)
            let bodies = { () -> Int? in
                #if DEBUG
                return HistoryPanelBudgetWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            let open = try #require(await w.element("suite.history.row.0"), "the panel shows no Open row")
            w.click(at: CGPoint(x: open.midX, y: open.midY))
            if let panel = Self.node("suite.history", in: w.host) { panel.setAccessibilityFocused?(true) }
            try await w.settle(untilStable: bodies)
            let jumped = HistoryPanelBudgetPage.jumps
            let step = try await w.measure("history-panel arrow walk, \(Self.steps) steps", bodies: bodies) {
                try await w.ticks(Self.steps) { _ in Self.press(NSDownArrowFunctionKey, keyCode: 125, in: w.window) }
            }
            _ = await w.element("suite.history.row.\(Self.steps)")
            let last = Self.node("suite.history.row.\(Self.steps)", in: w.host)
            #expect(last?.isAccessibilitySelected?() == true, "the arrows didn't walk the selection to step \(Self.steps)")
            #expect(HistoryPanelBudgetPage.jumps == jumped, "the arrows jumped \(HistoryPanelBudgetPage.jumps - jumped) times")
            expectBodies(step, atMost: 3, target: 0)
        }

        @Test(.timeLimit(.minutes(2))) func hoverInThreeBodies() async throws {
            let w = RenderBudgetWindow(HistoryPanelBudgetWindow())
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return HistoryPanelBudgetWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            let top = try #require(await w.element("suite.history.row.0"), "the panel shows no Open row")
            let bottom = try #require(await w.element("suite.history.row.11"), "the panel shows no step 11")
            let jumped = HistoryPanelBudgetPage.jumps
            let hover = try await w.measure("history-panel hover across rows, 120 samples", bodies: bodies) {
                try await w.ticks(120) { i in
                    let y = top.midY + (bottom.midY - top.midY) * Double(i) / 120
                    w.send(.mouseMoved, at: CGPoint(x: top.midX, y: y))
                }
            }
            #expect(HistoryPanelBudgetPage.jumps == jumped, "a hover jumped \(HistoryPanelBudgetPage.jumps - jumped) times")
            expectBodies(hover, atMost: 3, target: 0)
        }

        /// A key-down and key-up of `key` sent through `window`, which hands them to its first responder.
        static func press(_ key: Int, keyCode: UInt16, in window: NSWindow) {
            let characters = String(Character(UnicodeScalar(UInt16(key)) ?? " "))
            for kind in [NSEvent.EventType.keyDown, .keyUp] {
                guard let event = NSEvent.keyEvent(
                    with: kind, location: .zero, modifierFlags: [.numericPad, .function],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                    characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)
                else { Issue.record("no \(kind) event"); return }
                window.sendEvent(event)
            }
        }

        /// The first accessibility node called `identifier` under `element`, by its children and then its subviews.
        static func node(_ identifier: String, in element: Any, depth: Int = 0) -> AnyObject? {
            let node = element as AnyObject
            if (node.accessibilityIdentifier?() ?? nil) == identifier { return node }
            guard depth < 60 else { return nil }
            let children = ((node.accessibilityChildren?() ?? nil) ?? []) + ((node as? NSView)?.subviews ?? [])
            return children.lazy.compactMap { Self.node(identifier, in: $0, depth: depth + 1) }.first
        }
    }
}

/// The counted window: a header over the page, which owns the listing.
private struct HistoryPanelBudgetWindow: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("History").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText)
            HistoryPanelBudgetPage()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The gallery page's shape on "Open" and fifty undone steps: a jump moves the index and is counted.
private struct HistoryPanelBudgetPage: View {
    // view-static: main-actor
    static var jumps = 0
    @State private var listing = HistoryListing(
        base: "Open", steps: (1...BodyCountSuites.RenderBudgetHistoryPanelTests.steps).map { "Brush \($0)" }, index: 0)

    var body: some View {
        HistoryPanel(listing: listing) { index in
            Self.jumps += index == listing.index ? 0 : 1
            listing.index = index
        }
        .frame(maxWidth: SuiteSize.editorPanelWidth, maxHeight: .infinity)
    }
}
#endif
