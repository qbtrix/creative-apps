// Overlap.swift: the app audit's `overlap` check. Two enabled controls in the
// same layer may not cover each other, or one of them can't be clicked.
extension AppAudit {
    struct Overlap: Check {
        let id = "overlap"
        let fault = "#215: the inspector's divider sat over Photo's New Image toolbar button, which couldn't be clicked"
        let scope = Scope.all
        let summary = "Two enabled controls in one layer, neither inside the other, overlap by more than 2 pt both ways."

        var seeded: Fixture {
            Fixture(nodes: [
                Node(type: "button", frame: Rect(x: 10, y: 40, width: 40, height: 20)),
                Node(type: "button", frame: Rect(x: 40, y: 50, width: 40, height: 20)),
            ])
        }

        func run(_ screen: Screen) -> [Finding] {
            let live = screen.controls.filter(\.node.isEnabled)
            var findings = [Finding]()
            for (i, a) in live.enumerated() {
                for b in live[(i + 1)...] where a.layer == b.layer && !a.contains(b) && !b.contains(a) {
                    guard let va = a.visible, let vb = b.visible, let both = va.intersection(vb), both.width > 2, both.height > 2
                    else { continue }
                    let detail = "overlaps \(b.label) by \(Int(both.width)) x \(Int(both.height)) pt"
                    findings.append(Finding(item: a, detail: detail))
                }
            }
            return findings
        }
    }
}
