// DisabledDim.swift: the app audit's `disabled-dim` check. A disabled control
// must look dimmer than an enabled control of its type beside it, measured as
// ink in the screenshot (AuditPixels.swift).
extension AppAudit {
    struct DisabledDim: Check {
        let id = "disabled-dim"
        let fault = "#233 review: disabled top bar buttons looked enabled (EditorBarLabelStyle overrode the dimming)"
        let scope = Scope.all
        let summary = "A disabled control keeps more than 75% of the ink of the closest enabled control of its type."

        var seeded: Fixture {
            Fixture(
                nodes: [
                    Node(type: "button", frame: Rect(x: 10, y: 40, width: 40, height: 20)),
                    Node(type: "button", frame: Rect(x: 60, y: 40, width: 40, height: 20), isEnabled: false),
                ],
                paint: [(Rect(x: 15, y: 45, width: 10, height: 10), 0x55), (Rect(x: 65, y: 45, width: 10, height: 10), 0x55)])
        }

        func run(_ screen: Screen) -> [Finding] {
            let live = screen.controls.filter { $0.node.isEnabled && !$0.node.isSelected }
            return screen.controls.filter { !$0.node.isEnabled }.compactMap { off in
                let peers = live.filter { $0.node.type == off.node.type && $0.layer == off.layer }
                let siblings = peers.filter { $0.path.dropLast() == off.path.dropLast() }
                let row = peers.filter {
                    abs($0.node.frame.midY - off.node.frame.midY) <= 4 && abs($0.node.frame.height - off.node.frame.height) <= 4
                }
                // Like for like: the closest width first, so an icon-only
                // button meets an icon-only one, then the nearest.
                func key(_ item: Item) -> (Double, Double) {
                    (abs(item.node.frame.width - off.node.frame.width), item.distance(off))
                }
                guard let on = (siblings.isEmpty ? row : siblings).min(by: { key($0) < key($1) }),
                    let dim = screen.ink(off), let full = screen.ink(on), full >= 1.5
                else { return nil }
                let limit = 1 + 0.75 * (full - 1)
                return Finding(
                    item: off, detail: "ink \(ratio(dim)) vs \(ratio(full)) for enabled \(on.label)",
                    measured: Measure(value: dim, limit: limit), fails: dim > limit)
            }
        }
    }
}
