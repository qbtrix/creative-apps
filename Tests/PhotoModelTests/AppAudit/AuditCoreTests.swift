// AuditCoreTests.swift: the app audit's registry and engine. Every registered
// check has an id, a fault and a seed it must flag (a check that can't fail
// is dead); the tree walk skips what's scrolled out and finds layers; scopes
// pick apps. Runs on Linux and macOS (docs/blueprints/app-audit.md).
import Testing

private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> AppAudit.Rect {
    AppAudit.Rect(x: x, y: y, width: w, height: h)
}

@Test func everyCheckHasAnIdAFaultAndASummary() {
    let ids = AppAudit.checks.map(\.id)
    #expect(Set(ids).count == ids.count)
    for check in AppAudit.checks {
        #expect(check.id.allSatisfy { $0.isLowercase || $0 == "-" }, "\(check.id)")
        #expect(check.fault.contains("#") || check.fault.contains("docs/"), "\(check.id) names no fault")
        #expect(!check.summary.isEmpty, "\(check.id)")
    }
}

@Test(arguments: AppAudit.checks.map(\.id))
func everyCheckFlagsItsSeed(id: String) throws {
    let check = try #require(AppAudit.checks.first { $0.id == id })
    let report = AppAudit.report(check, on: check.seeded)
    #expect(report.counts[id, default: 0] >= 1, "\(id) passed its own seeded violation")
}

@Test func scrolledOutItemsHaveNoVisibleFrame() {
    let list = AppAudit.Node(type: "scrollView", frame: rect(0, 40, 200, 100), children: [
        AppAudit.Node(type: "button", frame: rect(0, 900, 200, 20)),
        AppAudit.Node(type: "button", frame: rect(0, 130, 200, 20)),
    ])
    let items = AppAudit.flatten(AppAudit.Node(type: "window", frame: rect(0, 0, 400, 300), children: [list]))
    #expect(items.map(\.visible) == [rect(0, 0, 400, 300), rect(0, 40, 200, 100), nil, rect(0, 130, 200, 10)])
}

@Test func layersAndDisabledAncestorsCarryDown() {
    var off = AppAudit.Node(type: "button", frame: rect(10, 10, 40, 20), isEnabled: false)
    off.children = [AppAudit.Node(type: "staticText", frame: rect(12, 12, 30, 14))]
    let sheet = AppAudit.Node(type: "sheet", frame: rect(0, 0, 200, 100), children: [off])
    let items = AppAudit.flatten(AppAudit.Node(type: "window", frame: rect(0, 0, 400, 300), children: [sheet]))
    #expect(items.map(\.layer) == [[], [], [0], [0]])
    #expect(items.map(\.inDisabledControl) == [false, false, false, true])
}

@Test func scopePicksTheApp() {
    struct PhotoOnly: AppAudit.Check {
        let id = "photo-only", fault = "#0", summary = "x", scope = AppAudit.Scope.app("photo")
        var seeded: AppAudit.Fixture { AppAudit.Fixture(nodes: []) }
        func run(_ screen: AppAudit.Screen) -> [AppAudit.Finding] { screen.items.map { AppAudit.Finding(item: $0) } }
    }
    let window = AppAudit.Node(type: "window", frame: rect(0, 0, 100, 100))
    func counts(_ app: String) -> [String: Int] {
        AppAudit.report("s", app: app, window: window, display: window.frame, image: nil, scale: 1, checks: [PhotoOnly()]).counts
    }
    #expect(counts("photo") == ["photo-only": 1])
    #expect(counts("flare").isEmpty)
}
