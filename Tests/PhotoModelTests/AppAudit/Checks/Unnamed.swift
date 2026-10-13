// Unnamed.swift: the app audit's `unnamed` check. A control VoiceOver can't
// name is a control a VoiceOver user can't use. Controls AppKit makes for
// itself (window buttons, "_XCUI:..."; outline disclosure triangles, "NS...")
// are the system's to name.
extension AppAudit {
    struct Unnamed: Check {
        let id = "unnamed"
        let fault =
            "docs/review-rubric.md: every icon-only control has an accessibility label; #63: keyframes VoiceOver can't reach"
        let scope = Scope.all
        let summary = "A control has no label, title or placeholder."

        var seeded: Fixture {
            Fixture(nodes: [Node(type: "textField", frame: Rect(x: 10, y: 40, width: 120, height: 22), identifier: "name")])
        }

        func run(_ screen: Screen) -> [Finding] {
            screen.controls.filter {
                $0.node.name.isEmpty && !$0.node.identifier.hasPrefix("_XCUI:") && !$0.node.identifier.hasPrefix("NS")
            }
            .map { Finding(item: $0, detail: "no label, title or placeholder") }
        }
    }
}
