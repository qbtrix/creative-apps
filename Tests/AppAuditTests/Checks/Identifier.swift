// Identifier.swift: the app audit's `identifier` check. Journeys find
// controls by accessibility identifier, so every control needs one.
extension AppAudit {
    struct Identifier: Check {
        let id = "identifier"
        let fault = "#262: XCUITest reads SwiftUI values as empty strings, so journeys find controls by identifier (#263 had to)"
        let scope = Scope.all
        let summary = "A control has no accessibility identifier."

        var seeded: Fixture {
            Fixture(nodes: [Node(type: "checkBox", frame: Rect(x: 10, y: 40, width: 16, height: 16), name: "Locked")])
        }

        func run(_ screen: Screen) -> [Finding] {
            screen.controls.filter(\.node.identifier.isEmpty).map { Finding(item: $0, detail: "no accessibility identifier") }
        }
    }
}
