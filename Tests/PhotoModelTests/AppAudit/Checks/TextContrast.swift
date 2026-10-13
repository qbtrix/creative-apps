// TextContrast.swift: the app audit's `contrast` check. Static text must meet
// WCAG's 4.5:1, or 3:1 for large text, measured as ink in the screenshot.
// Large text is guessed from the frame: at least 22 pt tall.
extension AppAudit {
    struct TextContrast: Check {
        let id = "contrast"
        let fault = "#62 and #101: marks nearly invisible on their background; #146: dimmed sidebar titles"
        let scope = Scope.all
        let summary = "Static text under 4.5:1 (3:1 when 22 pt or taller); text inside a disabled control is exempt."

        var seeded: Fixture {
            Fixture(
                nodes: [Node(type: "staticText", frame: Rect(x: 10, y: 40, width: 60, height: 14), name: "faint")],
                paint: [(Rect(x: 12, y: 42, width: 30, height: 10), 0xAA)])
        }

        func run(_ screen: Screen) -> [Finding] {
            screen.items.filter { $0.node.type == "staticText" && !$0.inDisabledControl }.compactMap { text in
                guard let value = screen.ink(text) else { return nil }
                let limit = text.node.frame.height >= 22 ? 3.0 : 4.5
                return Finding(
                    item: text, detail: "contrast \(ratio(value)), needs \(ratio(limit))",
                    measured: Measure(value: value, limit: limit), fails: value < limit)
            }
        }
    }
}
