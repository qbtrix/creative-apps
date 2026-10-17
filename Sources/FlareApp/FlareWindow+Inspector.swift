// FlareWindow+Inspector.swift: the router's inspector area
// (FlareWindow+Router.swift). Show Tab switches the inspector between
// Properties and Library (window state); the property rows wait for F6a and
// say so.
import FlareModel

extension FlareWindow {
    /// Acts on an inspector intent: Show Tab only, for now.
    func performInspector(_ intent: FlareIntent.Inspector) {
        switch intent {
        case .showTab(let id): if let tab = FlareInspectorTab(rawValue: id) { inspectorTab = tab }
        default: break
        }
    }

    /// Why an inspector intent can't act now; nil for Show Tab.
    func inspectorHelp(_ intent: FlareIntent.Inspector) -> String? {
        switch intent {
        case .showTab: nil
        default: "Not built yet (F6a)."
        }
    }
}
