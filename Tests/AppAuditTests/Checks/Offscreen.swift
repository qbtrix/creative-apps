// Offscreen.swift: the app audit's `offscreen` check. A control or list row
// that isn't scrolled out of view must sit inside the part of the window on
// the display (one in a sheet, popover or menu: on the display).
extension AppAudit {
    struct Offscreen: Check {
        let id = "offscreen"
        let fault = "#263: a 1280-wide window ran off the 1024 x 768 runner; #215: the window clipped its sidebar and inspector"
        let scope = Scope.all
        let summary = "A control or list row lies outside the visible window, with 1 pt of slack."

        var seeded: Fixture {
            Fixture(
                nodes: [Node(type: "button", frame: Rect(x: 330, y: 40, width: 40, height: 20), identifier: "far", name: "Far")],
                window: Rect(x: 0, y: 20, width: 400, height: 180))
        }

        func run(_ screen: Screen) -> [Finding] {
            screen.items.filter { (controls.contains($0.node.type) || rows.contains($0.node.type)) && $0.visible != nil }
                .compactMap { item in
                    guard let shown = item.visible else { return nil }
                    if let bounds = screen.bounds(item), bounds.contains(shown, slack: 1) { return nil }
                    return Finding(item: item, detail: "outside the visible \(item.layer.isEmpty ? "window" : "display")")
                }
        }
    }
}
