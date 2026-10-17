// AfterGlowJourneyTests+EveryControl.swift: SJ19 (blueprint suite.md 4.3,
// packet home.md Journey steps; HM-3b), the no-dead-controls sweep for the
// launcher on `weekOfWork`, as Flare's J29 (FlareJourneyTests+EveryControl.swift)
// with the `afterglow.` prefix. It reads every `afterglow.*` control from
// `suite.controls` (enabled, and its reason while disabled) and clicks each
// enabled one: the click must change the window shot, the control's value or
// selection, or the control list; then Escape. A control is judged as the list
// gives it now. The New tiles and their preset menus go last: a tile's click
// launches that app (the hand-off transport is live), so the launcher is
// brought back to the front before the next control; the harness's teardown
// ends every suite process. A listed control that nothing on screen carries
// (its id, or a part under `<id>.`) is recorded without stopping the sweep,
// so one such id still lets the run report every other control. Then the
// same on the Assets page (the sidebar's Assets row) and in the Settings
// window (⌘,) for the controls each registers; both are placeholders today
// and register none, which the log notes. This is a sweep, not feature coverage.
import XCTest

final class AfterGlowControlJourneys: XCTestCase {
    static let prefix = "afterglow."
    /// The New tiles and their preset menus, swept last: a click launches an app.
    static let launching = "afterglow.home.new."

    @MainActor func testEveryControlActsOrSaysWhy() {
        let suite = SuiteHarness(self)
        let home = suite.launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(home.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")
        XCTAssert(home.element("suite.sidebar").waitForExistence(timeout: 10), "the home window has no sidebar")
        let cards = home.app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'afterglow.home.card.'"))
        XCTAssert(cards.firstMatch.waitForExistence(timeout: 15), "the home shows no recent card")
        home.shot("controls")
        let listed = Self.listed(home)
        XCTAssertFalse(listed.isEmpty, "suite.controls lists no afterglow control")
        var swept = sweep(listed.map(\.id), home, page: "home")

        // The Assets page: the controls it adds to the home's.
        let assets = home.element("suite.sidebar").staticTexts["Assets"]
        XCTAssert(assets.waitForExistence(timeout: 5), "the sidebar has no Assets row")
        assets.click()
        XCTAssert(Self.text(containing: "Shared assets", home).waitForExistence(timeout: 5), "the Assets row showed no Assets page")
        home.shot("controls-assets")
        let onAssets = Self.listed(home).map(\.id).filter { !swept.contains($0) }
        if onAssets.isEmpty { print("SJ19: the Assets page registers no control of its own") }
        swept.formUnion(sweep(onAssets, home, page: "assets"))

        // The Settings window (⌘,): the controls it registers, if any.
        home.press(character: ",", .command)
        let settings = home.app.windows.matching(NSPredicate(format: "title != 'AfterGlow'")).firstMatch
        XCTAssert(settings.waitForExistence(timeout: 10), "⌘, opened no Settings window")
        home.shot("controls-settings", element: settings)
        let probe = settings.descendants(matching: .any)["suite.controls"].firstMatch
        let onSettings = probe.exists
            ? ((try? JSONDecoder().decode(ControlDocument.self, from: Data(probe.label.utf8)))?.controls ?? [])
                .map(\.id).filter { $0.hasPrefix(Self.prefix) && !swept.contains($0) }
            : []
        if onSettings.isEmpty { print("SJ19: the Settings window registers no control of its own") }
        _ = sweep(onSettings, home, page: "settings")
        home.press(character: "w", .command)
    }

    /// Clicks each enabled control of `ids` (judged as the list gives it now)
    /// and checks the click changed something; a disabled one must say why.
    /// Returns the ids it judged.
    @MainActor private func sweep(_ ids: [String], _ home: Journey, page: String) -> Set<String> {
        let order = ids.sorted { (Self.rank($0), $0) < (Self.rank($1), $1) }
        for id in order {
            guard let entry = Self.listed(home).first(where: { $0.id == id }) else { continue }
            guard entry.enabled else {
                XCTAssertFalse((entry.reason ?? "").isEmpty, "\(id) is disabled and doesn't say why")
                continue
            }
            bringBack(home)
            guard let control = Self.onScreen(id, home) else {
                home.note("\(id) is listed on the \(page) page but nothing on screen carries it (or <id>.<part>)")
                continue
            }
            let before = Self.state(of: control, home)
            control.click()
            Thread.sleep(forTimeInterval: 0.5)
            let changed = before != Self.state(of: control, home)
            home.shot("control-\(home.slug(id))")
            XCTAssert(changed, "\(id) is enabled but clicking it changed nothing")
            bringBack(home)
            home.press(.escape)
        }
        return Set(order)
    }

    /// The launcher to the front again when a click brought another app forward.
    @MainActor private func bringBack(_ home: Journey) {
        guard home.app.state != .runningForeground else { return }
        home.app.activate()
        _ = home.app.wait(for: .runningForeground, timeout: 10)
    }

    /// The New tiles and their presets sort after every other control.
    private static func rank(_ id: String) -> Int { id.hasPrefix(launching) ? 1 : 0 }

    /// The `afterglow.*` entries of `suite.controls` as listed now.
    @MainActor private static func listed(_ home: Journey) -> [ControlEntry] {
        (home.controls()?.controls ?? []).filter { $0.id.hasPrefix(prefix) }
    }

    /// The element carrying `id`, else the first part carrying `<id>.<part>`
    /// (a control registered with `identifies: false` leaves the ids to its
    /// parts); nil when neither is on screen within five seconds.
    @MainActor private static func onScreen(_ id: String, _ home: Journey) -> XCUIElement? {
        let control = home.element(id)
        if control.waitForExistence(timeout: 5) { return control }
        let part = home.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", id + ".")).firstMatch
        return part.exists ? part : nil
    }

    /// What a click may change: the window shot, the control's value and
    /// selection, and the control list's JSON.
    @MainActor private static func state(of control: XCUIElement, _ home: Journey) -> [String] {
        let shot = home.app.windows.firstMatch.screenshot().pngRepresentation.base64EncodedString()
        let value = control.exists ? "\(control.value ?? "") \(control.isSelected)" : "gone"
        return [shot, value, home.element("suite.controls").label]
    }

    /// A text whose label or value contains `words` (a plain Text reads its words as its value on macOS).
    @MainActor private static func text(containing words: String, _ home: Journey) -> XCUIElement {
        home.app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", words, words)).firstMatch
    }
}

private extension Journey {
    /// Records `message` as a failure without ending the journey, as the audit does.
    func note(_ message: String) {
        let stops = test.continueAfterFailure
        test.continueAfterFailure = true
        XCTFail(message)
        test.continueAfterFailure = stops
    }
}
