// AfterGlowToolbarIdentifierTests.swift: the real HomeWindow in a titled
// window, its accessibility tree read in process the way the app audit's
// identifier check reads it from the journeys (#6204). With the AI Access
// chip in the title bar (testAIAccessApproval), which collapses the search
// item into a Search button at 880, and under a sheet (testConnectAssistant),
// where accessibility reads the search field's cell, and under the Help
// menu's Connect an AI Assistant sheet (help-connect), every control keeps an
// identifier. AppKit exposes the field's Search and cancel buttons as proxies
// that don't adopt NSAccessibilityProtocol, so the walk reads those through the
// attribute API, the way the accessibility server does. The window's minimum width keeps AppKit's "more toolbar items"
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

    /// help-connect: the Help menu's sheet, begun by the same presenter, over the full-width field.
    @Test(.timeLimit(.minutes(3))) func helpSheetLeavesNoUnnamedControl() async throws {
        let window = Self.window()
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(800))
        let presenter = SuiteHelpPresenter.shared
        presenter.showConnect(bundle: "/Applications/AfterGlow.app", in: window)
        defer { presenter.closeConnect() }
        try await Task.sleep(for: .milliseconds(800))
        #expect(window.attachedSheet != nil, "Connect an AI Assistant began no sheet")
        #expect(Self.controls(in: window).contains { $0.id == "afterglow.home.search.search" },
                "the walk never reached the field's Search button")
        // AppKit can swap the field's Search button cell with the sheet up and no event after it, so no window
        // update names the new one; under the Help sheets the journeys' audit read that cell unnamed.
        let cell = try #require(Self.searchCell(in: window), "no toolbar search field")
        cell.searchButtonCell = NSButtonCell()
        try await Task.sleep(for: .milliseconds(1500))
        let unnamed = Self.unnamedControls(in: window)
        #expect(unnamed.isEmpty, "controls with no identifier under the Connect sheet: \(unnamed)")
    }

    /// The toolbar search item's field cell.
    static func searchCell(in window: NSWindow) -> NSSearchFieldCell? {
        window.toolbar?.items.lazy.compactMap { ($0 as? NSSearchToolbarItem)?.searchField.cell as? NSSearchFieldCell }.first
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
        controls(in: window).filter(\.id.isEmpty).map(\.description)
    }

    /// Each exposed control under the window: its identifier and "role 'label' frame type".
    static func controls(in window: NSWindow) -> [(id: String, description: String)] {
        var found: [(id: String, description: String)] = []
        var seen = Set<ObjectIdentifier>()
        // The title bar's close, minimize and zoom buttons: XCUITest names them itself.
        let widgets: Set<String> = [NSAccessibility.Subrole.closeButton, .minimizeButton, .zoomButton, .fullScreenButton]
            .map(\.rawValue).reduce(into: []) { $0.insert($1) }
        func walk(_ element: Any, depth: Int) {
            guard depth < 40, let object = element as? NSObject, seen.insert(ObjectIdentifier(object)).inserted,
                  let node = AXNode(object) else { return }
            if node.isElement, let role = node.role, !widgets.contains(node.subrole ?? ""),
               controlRoles.map(\.rawValue).contains(role) || role == "AXSearchField" || node.subrole == "AXSearchField" {
                found.append((node.identifier, "\(role) '\(node.label)' \(node.frame) \(type(of: object))"))
            }
            for child in node.children { walk(child, depth: depth + 1) }
        }
        walk(window, depth: 0)
        return found
    }

    /// One accessibility element read through NSAccessibilityProtocol, or, for AppKit's proxies (a search field's
    /// buttons) that don't adopt it, through the attribute API the accessibility server uses.
    struct AXNode {
        var isElement = true, role: String?, subrole: String?, identifier = "", label = "", frame = CGRect.zero
        var children: [Any] = []

        init?(_ object: NSObject) {
            if let node = object as? NSAccessibilityProtocol {
                isElement = node.isAccessibilityElement()
                role = node.accessibilityRole()?.rawValue
                subrole = node.accessibilitySubrole()?.rawValue
                identifier = (node.accessibilityIdentifier() as String?) ?? ""
                label = node.accessibilityLabel() ?? node.accessibilityTitle() ?? ""
                frame = node.accessibilityFrame()
                children = node.accessibilityChildren() ?? []
            } else if object.responds(to: #selector(NSObject.accessibilityAttributeValue(_:))) {
                func value<T>(_ name: NSAccessibility.Attribute) -> T? { object.accessibilityAttributeValue(name) as? T }
                // SwiftUI's own nodes answer the attribute API but not accessibilityIsIgnored.
                isElement = !object.responds(to: #selector(NSObject.accessibilityIsIgnored)) || !object.accessibilityIsIgnored()
                role = value(.role)
                subrole = value(.subrole)
                identifier = value(.identifier) ?? ""
                label = value(.description) ?? value(.title) ?? ""
                children = value(.children) ?? []
            } else { return nil }
        }
    }
}
#endif
