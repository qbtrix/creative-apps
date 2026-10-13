// Audit.swift: the app audit at a journey screen (docs/blueprints/app-audit.md).
// `shot` audits every window shot, and `audit("step")` audits the window as
// it is now as screen "<app>-<step>": one snapshot of the first window's
// element tree, the main screen's pixels, every registered check
// (Tests/AppAuditTests/, compiled in by project.yml), the report
// attached as "audit-<app>-<step>.json", and the app's tally of distinct
// violations held against its line in UITests/audit-baseline.json. A count
// that rises fails at the screen that raised it; the bundle's last test
// fails for a count that fell (see `Journey.init`).
//
// The test runner is sandboxed with read-only access to "/": it reads the
// baseline from the repo, and the report leaves only as an attachment, which
// scripts/ui-test exports into ui-screens. An audit failure doesn't stop the
// journey, so one run reports every screen.
import AppKit
import XCTest

extension Journey {
    func audit(_ step: String) {
        let screen = "\(name)-\(step)"
        let png = steadyScreen()
        let tree: any XCUIElementSnapshot
        do {
            if AuditRun.tallies[name] == nil {
                let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "audit-baseline.json")
                let baselines = try JSONDecoder().decode([String: [String: Int]].self, from: Data(contentsOf: file))
                AuditRun.tallies[name] = AppAudit.Tally(app: name, baseline: baselines[name])
            }
            tree = try app.windows.firstMatch.snapshot()
        } catch {
            return record(["audit \(screen) didn't run: \(error)"])
        }
        // Element frames are in points from the main screen's top left; the
        // scale maps them onto the screenshot, 1x runner or 2x laptop alike.
        let size = NSScreen.screens.first?.frame.size ?? .zero
        let (width, height) = (Double(size.width), Double(size.height))
        let image = width > 0 ? pixels(png) : nil
        let report = AppAudit.report(
            screen, app: name, window: node(tree), display: AppAudit.Rect(x: 0, y: 0, width: width, height: height),
            image: image, scale: image.map { Double($0.width) / width } ?? 1)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let json = try? encoder.encode(report) {
            let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
            attachment.name = "audit-\(screen)"
            attachment.lifetime = .keepAlways
            test.add(attachment)
        }
        record(AuditRun.tallies[name]?.add(report) ?? [])
    }

    /// After the app's last journey: fails for each check whose distinct
    /// count fell under the baseline, so the baseline comes down with it.
    func auditLower() {
        guard let tally = AuditRun.tallies[name] else { return }
        print("audit \(name): \(tally.seen.mapValues(\.count).sorted { $0.key < $1.key })")
        record(tally.lower())
    }

    /// The main screen once two shots a quarter second apart match (at most
    /// seven shots), so a focus ring or hover still fading in doesn't decide a
    /// pixel check. A blinking caret never settles; the last shot is used.
    private func steadyScreen() -> Data {
        var last = XCUIScreen.main.screenshot().pngRepresentation
        for _ in 0..<6 {
            Thread.sleep(forTimeInterval: 0.25)
            let next = XCUIScreen.main.screenshot().pngRepresentation
            if next == last { break }
            last = next
        }
        return last
    }

    /// Records each message as a failure without ending the journey.
    private func record(_ failures: [String]) {
        let stops = test.continueAfterFailure
        test.continueAfterFailure = true
        for failure in failures { XCTFail(failure) }
        test.continueAfterFailure = stops
    }

    private func node(_ element: any XCUIElementSnapshot) -> AppAudit.Node {
        let f = element.frame
        return AppAudit.Node(
            type: Self.types[element.elementType] ?? "other",
            frame: AppAudit.Rect(x: Double(f.minX), y: Double(f.minY), width: Double(f.width), height: Double(f.height)),
            identifier: element.identifier,
            name: [element.label, element.title, element.placeholderValue ?? ""].first { !$0.isEmpty } ?? "",
            isEnabled: element.isEnabled, isSelected: element.isSelected,
            children: element.children.map(node))
    }

    /// The PNG as sRGB RGBA, top row first.
    private func pixels(_ png: Data) -> AppAudit.Image? {
        guard let image = NSBitmapImageRep(data: png)?.cgImage, let srgb = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        let (width, height) = (image.width, image.height)
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? AppAudit.Image(width: width, height: height, rgba: rgba) : nil
    }

    /// The element types the checks look at; everything else is "other".
    private static let types: [XCUIElement.ElementType: String] = [
        .button: "button", .toolbarButton: "toolbarButton", .checkBox: "checkBox", .radioButton: "radioButton",
        .switch: "switch", .toggle: "toggle", .slider: "slider", .stepper: "stepper",
        .incrementArrow: "incrementArrow", .decrementArrow: "decrementArrow", .popUpButton: "popUpButton",
        .menuButton: "menuButton", .comboBox: "comboBox", .textField: "textField",
        .secureTextField: "secureTextField", .searchField: "searchField", .textView: "textView", .link: "link",
        .colorWell: "colorWell", .disclosureTriangle: "disclosureTriangle", .tab: "tab", .datePicker: "datePicker",
        .cell: "cell", .outlineRow: "outlineRow", .tableRow: "tableRow", .staticText: "staticText",
        .scrollView: "scrollView", .window: "window", .sheet: "sheet", .popover: "popover", .dialog: "dialog",
        .alert: "alert", .menu: "menu", .drawer: "drawer",
    ]
}

/// Each app's tally, kept across the tests of its bundle (one app per runner
/// process).
@MainActor private enum AuditRun {
    static var tallies: [String: AppAudit.Tally] = [:]
}
