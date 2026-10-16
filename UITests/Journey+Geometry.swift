// Journey+Geometry.swift: the editor window's shared steps
// (docs/blueprints/suiteui/features/editor-in-window.md, EW-4).
// `expectEditorWindow()` checks the five regions of a SuiteWindow that holds
// an editor are up and hittable; `expectShellGeometry()` reads their frames,
// the window's and the display's visible frame, and fails with the rules
// ShellGeometry (Tests/AppAuditTests/ShellGeometry.swift, compiled into every
// bundle by project.yml and tested on Linux) finds broken.
//
// Element frames are in points from the main screen's top left; NSScreen
// frames start at its bottom left, so the visible frame is flipped against the
// main screen's height. The window has to fit the visible frame (about
// 1024 × 737 on the 1024 × 768 runner, under its menu bar); nothing here
// assumes an exact 768.
import AppKit
import XCTest

extension Journey {
    /// The regions of an editor in a SuiteWindow, by accessibility identifier.
    static let editorRegions = ["suite.sidebar", "suite.viewport", "suite.status", "suite.inspector", "suite.tools"]

    /// The columns no two of which may overlap by more than a hairline.
    static let editorColumns = ["suite.sidebar", "suite.viewport", "suite.status", "suite.inspector"]

    /// The window is up with the sidebar, viewport, status line, inspector and
    /// tool palette, each hittable, and its toolbar; shoots "launch".
    func expectEditorWindow() {
        XCTAssert(app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(element("suite.viewport").waitForExistence(timeout: 5), "no viewport (suite.viewport)")
        for identifier in Self.editorRegions {
            let region = element(identifier)
            XCTAssert(region.exists, "no \(identifier)")
            XCTAssert(region.isHittable, "\(identifier) isn't hittable")
        }
        XCTAssert(app.toolbars.firstMatch.exists, "no window toolbar")
        shot("launch")
    }

    /// Fails with every geometry rule the window breaks: the window inside the
    /// display's visible frame; the editor regions and the toolbar inside the
    /// window; no two columns overlapping by more than 1 pt; each region in
    /// `minimums` (by identifier, or "toolbar") at least that size; each
    /// `clear` pair not intersecting. `regions` adds elements a caller names
    /// (a ruler, a grown artboard) for `minimums` and `clear`.
    func expectShellGeometry(
        minimums: [String: (width: Double, height: Double)] = [:],
        regions extra: [String: XCUIElement] = [:],
        clear: [(String, String)] = []
    ) {
        let window = app.windows.firstMatch
        XCTAssert(window.waitForExistence(timeout: 30), "no window opened")
        let frame = rect(window.frame)
        var found = ShellGeometry.violations(
            window: visibleFrame(around: frame), regions: ["window": frame],
            minimums: [:], apart: [], clear: [], container: "display's visible frame")

        var regions: [String: AppAudit.Rect] = [:]
        for identifier in Self.editorRegions {
            let region = element(identifier)
            if region.exists { regions[identifier] = rect(region.frame) }
        }
        let toolbar = app.toolbars.firstMatch
        if toolbar.exists { regions["toolbar"] = rect(toolbar.frame) }
        for (key, item) in extra where item.exists { regions[key] = rect(item.frame) }

        var apart: [(String, String)] = []
        for (index, first) in Self.editorColumns.enumerated() {
            for second in Self.editorColumns.dropFirst(index + 1) { apart.append((first, second)) }
        }
        let required = Dictionary(uniqueKeysWithValues: (Self.editorRegions + ["toolbar"]).map { ($0, (width: 1.0, height: 1.0)) })
        found += ShellGeometry.violations(
            window: frame, regions: regions, minimums: required.merging(minimums) { $1 }, apart: apart, clear: clear)
        XCTAssert(found.isEmpty, "shell geometry of \(name):\n" + found.joined(separator: "\n"))
    }

    /// The visible frame of the screen the window's center is on (the main
    /// screen when none holds it), flipped to top-left points.
    private func visibleFrame(around window: AppAudit.Rect) -> AppAudit.Rect {
        let screens = NSScreen.screens
        let height = Double(screens.first?.frame.height ?? 0)
        let flipped = screens.map { screen -> (frame: AppAudit.Rect, visible: AppAudit.Rect) in
            (flip(screen.frame, height: height), flip(screen.visibleFrame, height: height))
        }
        let (midX, midY) = (window.x + window.width / 2, window.y + window.height / 2)
        let holder = flipped.first { $0.frame.x <= midX && midX < $0.frame.maxX && $0.frame.y <= midY && midY < $0.frame.maxY }
        return (holder ?? flipped.first)?.visible ?? AppAudit.Rect(x: 0, y: 0, width: 0, height: 0)
    }

    private func flip(_ frame: CGRect, height: Double) -> AppAudit.Rect {
        AppAudit.Rect(
            x: Double(frame.minX), y: height - Double(frame.maxY), width: Double(frame.width), height: Double(frame.height))
    }

    private func rect(_ frame: CGRect) -> AppAudit.Rect {
        AppAudit.Rect(x: Double(frame.minX), y: Double(frame.minY), width: Double(frame.width), height: Double(frame.height))
    }
}
