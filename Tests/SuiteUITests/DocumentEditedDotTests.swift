// DocumentEditedDotTests.swift: `.suiteDocumentEdited(_:)` on an offscreen window sets
// the window's edited dot (NSWindow.isDocumentEdited) when its view lands and on each
// change of the flag, and clears it again. Its `suite.window.edited` element, found
// through accessibility children alone (the path XCUITest reads), says "edited" or
// "saved" after the window's flag, even when the window's flag and the model's disagree.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor @Observable private final class Dirty {
    var edited = true
}

private struct Edited: View {
    let dirty: Dirty
    var body: some View { Text("Poster").suiteDocumentEdited(dirty.edited) }
}

@MainActor @Suite struct DocumentEditedDotTests {
    @Test func theDotFollowsTheFlag() async throws {
        let dirty = Dirty()
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 320, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.orderOut(nil) }
        window.contentView = NSHostingView(rootView: Edited(dirty: dirty))
        window.orderFrontRegardless()
        #expect(await settles { window.isDocumentEdited }, "an edited document left the dot off")
        dirty.edited = false
        #expect(await settles { !window.isDocumentEdited }, "a saved document left the dot on")
        dirty.edited = true
        #expect(await settles { window.isDocumentEdited }, "a new edit didn't set the dot again")
    }

    @Test func theElementReadsTheWindowsFlag() async throws {
        for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
        }
        let dirty = Dirty()
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 320, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.orderOut(nil) }
        window.contentView = NSHostingView(rootView: Edited(dirty: dirty))
        window.orderFrontRegardless()
        #expect(await settles { label(in: window) == "edited" }, "an edited window's element read \(label(in: window) ?? "nothing")")
        let element = try #require(element(in: window))
        #expect((element as? NSObject)?.value(forKey: "accessibilityValue") as? String == "edited")
        #expect((element.accessibilityRole?() ?? nil) == .group, "the element is a control or text the app audit would judge")
        dirty.edited = false
        #expect(await settles { label(in: window) == "saved" }, "a saved window's element read \(label(in: window) ?? "nothing")")
        // The window's flag, not the model's: set the window alone and the element follows it.
        window.isDocumentEdited = true
        #expect(label(in: window) == "edited", "the element read the model's flag, not the window's")
    }

    /// The `suite.window.edited` element, walking accessibility children only, as XCUITest does.
    private func element(in window: NSWindow) -> AnyObject? {
        func find(_ node: AnyObject, _ depth: Int) -> AnyObject? {
            if (node.accessibilityIdentifier?() ?? nil) == "suite.window.edited" { return node }
            guard depth < 40 else { return nil }
            for child in (node.accessibilityChildren?() ?? nil) ?? [] {
                if let found = find(child as AnyObject, depth + 1) { return found }
            }
            return nil
        }
        return window.contentView.flatMap { find($0, 0) }
    }

    private func label(in window: NSWindow) -> String? { element(in: window)?.accessibilityLabel?() ?? nil }

    /// Lets the main actor run until `condition` holds, at most two seconds.
    private func settles(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return true
    }
}
