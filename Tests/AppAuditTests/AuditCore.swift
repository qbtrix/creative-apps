// AuditCore.swift: the app audit's engine (docs/blueprints/app-audit.md): the
// registry of checks, the plain element tree they read, the screen they run
// on and the per-screen report. AuditTally.swift holds the counts against the
// baseline.
//
// A check is one file in Checks/ conforming to `AppAudit.Check` plus one entry
// in `AppAudit.checks`; nothing else changes. Every check carries the fault
// that created it and a seeded screen it must flag, and AuditCoreTests runs
// each registered check on its own seed, so a check that can't fail can't
// land. Placement and naming: see AuditPixels.swift.
import Foundation

extension AppAudit {
    /// Every check the audit runs. Add a check here and in its own file.
    static let checks: [any Check] = [DisabledDim(), Overlap(), TextContrast(), Identifier(), Offscreen(), Unnamed()]

    /// One rule, born from one fault.
    protocol Check: Sendable {
        /// The baseline key: "disabled-dim".
        var id: String { get }
        /// The PR or issue that created the rule and what went wrong:
        /// "#233 review: disabled bar buttons looked enabled".
        var fault: String { get }
        var scope: Scope { get }
        /// What fails, in one line.
        var summary: String { get }
        /// A tiny screen the check must flag.
        var seeded: Fixture { get }
        func run(_ screen: Screen) -> [Finding]
    }

    /// The apps a check runs on: all, or one by its lowercased name ("photo").
    enum Scope: Equatable, Sendable {
        case all
        case app(String)
    }

    /// One element of the window's tree. `type` is the XCUIElement.ElementType
    /// case name ("button"; "other" for types the audit ignores), `frame` is in
    /// screen points, `name` is what VoiceOver reads: the label, else the
    /// title, else the placeholder.
    struct Node: Sendable {
        var type: String
        var frame: Rect
        var identifier = ""
        var name = ""
        var isEnabled = true
        var isSelected = false
        var children: [Node] = []
    }

    /// What a check reports about one element: a violation, or (with
    /// `fails` false) a passing pixel measurement kept for tuning limits.
    struct Finding: Sendable {
        let item: Item
        var detail = ""
        var measured: Measure?
        var fails = true
    }

    struct Measure: Codable, Equatable, Sendable {
        let value: Double
        let limit: Double
    }

    /// A seeded screen: `nodes` in a window, painted as grey `paint` fills on
    /// a white 320 x 220 display (no paint: no screenshot).
    struct Fixture: Sendable {
        var nodes: [Node]
        var app = "app"
        var window = Rect(x: 0, y: 20, width: 300, height: 180)
        var paint: [(rect: Rect, grey: UInt8)] = []
    }

    static let controls: Set<String> = [
        "button", "toolbarButton", "checkBox", "radioButton", "switch", "toggle", "slider", "stepper",
        "incrementArrow", "decrementArrow", "popUpButton", "menuButton", "comboBox", "textField",
        "secureTextField", "searchField", "textView", "link", "colorWell", "disclosureTriangle", "tab",
        "datePicker",
    ]
    static let rows: Set<String> = ["cell", "outlineRow", "tableRow"]
    static let layers: Set<String> = ["sheet", "popover", "dialog", "alert", "menu", "drawer"]
    static let modals: Set<String> = ["sheet", "dialog", "alert"]

    /// A node with where it sits: its index path, its frame cut by the scroll
    /// views around it (nil when scrolled out), the path of the sheet, popover
    /// or menu it is in ([] for the window), and whether a disabled control
    /// holds it.
    struct Item: Sendable {
        let node: Node
        let path: [Int]
        let visible: Rect?
        let layer: [Int]
        let inDisabledControl: Bool

        var label: String {
            let name = node.identifier.isEmpty ? node.name : node.identifier
            return "\(node.type) '\(name.prefix(40))'"
        }
        func contains(_ other: Item) -> Bool { other.path.starts(with: path) }
        func distance(_ other: Item) -> Double {
            hypot(node.frame.midX - other.node.frame.midX, node.frame.midY - other.node.frame.midY)
        }
    }

    /// One audited screen: what every check reads.
    struct Screen: Sendable {
        let app: String
        let window: Rect
        let display: Rect
        let items: [Item]
        let image: Image?
        let scale: Double

        /// Controls not scrolled out of view.
        var controls: [Item] { items.filter { AppAudit.controls.contains($0.node.type) && $0.visible != nil } }
        /// A sheet, dialog or alert is up. macOS dims the window behind it on
        /// purpose, so pixel checks skip that window's own elements.
        var modal: Bool { items.contains { modals.contains($0.node.type) } }

        /// Where `item` may sit: the window on the display, or for an item in
        /// a sheet, popover or menu the display.
        func bounds(_ item: Item) -> Rect? { item.layer.isEmpty ? window.intersection(display) : display }

        /// The ink of the part of `item` that is on screen; nil without a
        /// screenshot, behind a modal, or when too little of it shows.
        func ink(_ item: Item) -> Double? {
            guard let image, !(modal && item.layer.isEmpty), let bounds = bounds(item),
                let seen = item.visible?.intersection(bounds)
            else { return nil }
            let pixels = Rect(x: seen.x * scale, y: seen.y * scale, width: seen.width * scale, height: seen.height * scale)
            return AppAudit.ink(of: image, in: pixels)?.contrast
        }
    }

    struct Violation: Codable, Equatable, Sendable {
        let check: String
        let element: String
        let frame: Rect
        let detail: String
    }

    struct Sample: Codable, Equatable, Sendable {
        let check: String
        let element: String
        let measure: Measure
    }

    /// One screen's audit, attached as audit-<screen>.json.
    struct Report: Codable, Sendable {
        let screen: String
        let app: String
        let scale: Double
        let display: Rect
        let window: Rect
        let modal: Bool
        let counts: [String: Int]
        let violations: [Violation]
        let samples: [Sample]
    }

    /// Runs every check in `checks` whose scope covers `app` on one screen.
    static func report(
        _ name: String, app: String, window: Node, display: Rect, image: Image?, scale: Double,
        checks: [any Check] = checks
    ) -> Report {
        let screen = Screen(
            app: app, window: window.frame, display: display, items: flatten(window), image: image, scale: scale)
        var counts = [String: Int](), violations = [Violation](), samples = [Sample]()
        for check in checks where check.scope == .all || check.scope == .app(app) {
            counts[check.id] = 0
            for finding in check.run(screen) {
                let element = finding.item.label
                if let measure = finding.measured { samples.append(Sample(check: check.id, element: element, measure: measure)) }
                guard finding.fails else { continue }
                counts[check.id, default: 0] += 1
                violations.append(
                    Violation(check: check.id, element: element, frame: finding.item.node.frame, detail: finding.detail))
            }
        }
        return Report(
            screen: name, app: app, scale: scale, display: display, window: window.frame, modal: screen.modal,
            counts: counts, violations: violations, samples: samples)
    }

    /// Runs `check` on its seeded screen.
    static func report(_ check: any Check, on fixture: Fixture) -> Report {
        let (width, height) = (320, 220)
        var image: Image?
        if !fixture.paint.isEmpty {
            var rgba = [UInt8](repeating: 255, count: width * height * 4)
            for fill in fixture.paint {
                for y in Int(fill.rect.y)..<Int(fill.rect.maxY) {
                    for x in Int(fill.rect.x)..<Int(fill.rect.maxX) where (0..<width).contains(x) && (0..<height).contains(y) {
                        let i = (y * width + x) * 4
                        rgba.replaceSubrange(i..<i + 3, with: [fill.grey, fill.grey, fill.grey])
                    }
                }
            }
            image = Image(width: width, height: height, rgba: rgba)
        }
        let window = Node(type: "window", frame: fixture.window, children: fixture.nodes)
        let display = Rect(x: 0, y: 0, width: Double(width), height: Double(height))
        return report("seeded", app: fixture.app, window: window, display: display, image: image, scale: 1, checks: [check])
    }

    /// "4.06:1".
    static func ratio(_ value: Double) -> String { String(format: "%.2f:1", value) }

    static func flatten(_ window: Node) -> [Item] {
        var items = [Item]()
        // `clip` is the visible part of the nearest scroll view; .zero once
        // that is nothing, so everything inside is skipped.
        func walk(_ node: Node, _ path: [Int], clip: Rect?, layer: [Int], disabled: Bool) {
            let visible = node.frame.intersection(clip ?? node.frame)
            items.append(Item(node: node, path: path, visible: visible, layer: layer, inDisabledControl: disabled))
            for (i, child) in node.children.enumerated() {
                walk(
                    child, path + [i], clip: node.type == "scrollView" ? visible ?? .zero : clip,
                    layer: layers.contains(node.type) ? path : layer,
                    disabled: disabled || (controls.contains(node.type) && !node.isEnabled))
            }
        }
        walk(window, [], clip: nil, layer: [], disabled: false)
        return items
    }
}

extension AppAudit.Rect {
    static let zero = Self(x: 0, y: 0, width: 0, height: 0)
    var midX: Double { x + width / 2 }
    var midY: Double { y + height / 2 }

    /// The overlap of two rects, nil when it has no area.
    func intersection(_ other: Self) -> Self? {
        let left = max(x, other.x), top = max(y, other.y)
        let right = min(maxX, other.maxX), bottom = min(maxY, other.maxY)
        return right > left && bottom > top ? Self(x: left, y: top, width: right - left, height: bottom - top) : nil
    }

    func contains(_ other: Self, slack: Double) -> Bool {
        other.x >= x - slack && other.y >= y - slack && other.maxX <= maxX + slack && other.maxY <= maxY + slack
    }
}
