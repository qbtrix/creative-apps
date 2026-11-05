// AfterGlowToolbarIdentifierTests.swift: the real HomeWindow in a titled
// window, its accessibility tree read in process the way the app audit's
// identifier check reads it from the journeys (#6204). With the AI Access
// chip in the title bar (testAIAccessApproval), which collapses the search
// item into a Search button at 880, and under a sheet (testConnectAssistant),
// where accessibility reads the search field's cell and AppKit can swap its
// button cells as the window gives up key, every control keeps an identifier. The window's minimum width keeps AppKit's "more toolbar items"
// pop-up from showing here; the journeys' audit covers it. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import AfterGlowApp
@testable import SuiteShell

@MainActor @Suite struct AfterGlowToolbarIdentifierTests {
    @Test(.timeLimit(.minutes(3)), arguments: [1000.0, 880.0])
    func chipLeavesNoUnnamedControl(width: Double) async throws {
        let window = Self.window(width: width)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(800))
        let center = AIAccessCenter()
        center.start(app: .launcher, arguments: [])
        center.request(client: FakeAIAccess.demoClient, in: window)
        try await Task.sleep(for: .milliseconds(300))
        center.decide(.allowOnce)
        try await Task.sleep(for: .milliseconds(800))
        #expect(window.titlebarAccessoryViewControllers.count == 1, "no chip after Allow Once")
        let unnamed = Self.unnamedControls(in: window)
        #expect(unnamed.isEmpty, "controls with no identifier: \(unnamed)")
        center.stop()
    }

    @Test(.timeLimit(.minutes(3))) func sheetLeavesNoUnnamedControl() async throws {
        let window = Self.window()
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(800))
        let sheet = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        sheet.isReleasedWhenClosed = false
        window.beginSheet(sheet, completionHandler: nil)
        try await Task.sleep(for: .milliseconds(800))
        let unnamed = Self.unnamedControls(in: window)
        window.endSheet(sheet)
        #expect(unnamed.isEmpty, "controls with no identifier under a sheet: \(unnamed)")
    }

    /// AppKit can swap the field's button cells as the window gives up key to a sheet, with no window update after
    /// it (Help > Connect…, testConnectAssistant): beginning the sheet names the new cells all the same.
    @Test(.timeLimit(.minutes(3))) func sheetNamesSwappedButtonCells() async throws {
        let window = Self.window()
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(800))
        let item = try #require(window.toolbar?.items.lazy.compactMap { $0 as? NSSearchToolbarItem }.first)
        let cell = try #require(item.searchField.cell as? NSSearchFieldCell)
        cell.searchButtonCell = NSButtonCell()
        cell.cancelButtonCell = NSButtonCell()
        SuiteHelpPresenter.shared.showConnect(bundle: "/fixture/AfterGlow.app", in: window)
        defer { SuiteHelpPresenter.shared.closeConnect() }
        try await Task.sleep(for: .milliseconds(1500))
        #expect(window.attachedSheet != nil, "no Connect sheet")
        #expect(cell.searchButtonCell?.accessibilityIdentifier() == "afterglow.home.search.search")
        #expect(cell.cancelButtonCell?.accessibilityIdentifier() == "afterglow.home.search.cancel")
    }

    /// The home window at the journeys' 1000 by 640, titled so the hosting controller bridges its toolbar.
    static func window(width: Double = 1000) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: HomeWindow(services: .fake(), support: "/fixture")))
        window.styleMask = [.titled, .resizable, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setFrame(CGRect(x: -20_000, y: -20_000, width: width, height: 640), display: false)
        window.orderFrontRegardless()
        return window
    }

    /// The roles the audit counts as controls, outside the sheet's own window.
    static let controlRoles: Set<NSAccessibility.Role> = [
        .button, .popUpButton, .menuButton, .checkBox, .radioButton, .slider, .comboBox, .textField, .incrementor,
        .colorWell, .disclosureTriangle,
    ]

    /// Each exposed control under the window with an empty identifier, as "role 'label' frame".
    static func unnamedControls(in window: NSWindow) -> [String] {
        var found: [String] = []
        var seen = Set<ObjectIdentifier>()
        func walk(_ element: Any, depth: Int) {
            guard depth < 40, let object = element as? NSObject, seen.insert(ObjectIdentifier(object)).inserted,
                  let node = element as? NSAccessibilityProtocol else { return }
            // The title bar's close, minimize and zoom buttons: XCUITest names them itself.
            let widgets: Set<NSAccessibility.Subrole> = [.closeButton, .minimizeButton, .zoomButton, .fullScreenButton]
            if node.isAccessibilityElement(), let role = node.accessibilityRole(),
               !widgets.contains(node.accessibilitySubrole() ?? .unknown),
               controlRoles.contains(role) || role.rawValue == "AXSearchField" || node.accessibilitySubrole() == .searchField,
               ((node.accessibilityIdentifier() as String?) ?? "").isEmpty {
                let label = node.accessibilityLabel() ?? node.accessibilityTitle() ?? ""
                let parent = (node.accessibilityParent() as? NSObject).map { String(describing: type(of: $0)) } ?? "-"
                found.append("\(role.rawValue) '\(label)' \(node.accessibilityFrame()) \(type(of: object)) in \(parent)")
            }
            for child in node.accessibilityChildren() ?? [] { walk(child, depth: depth + 1) }
        }
        walk(window, depth: 0)
        return found
    }
}
#endif
