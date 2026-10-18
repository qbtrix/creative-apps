// SuiteAlerts.swift: the alerts every app shows the same way. A problem alert
// shows one sentence (a failed open or save, a refused edit) as the alert's
// title with a single OK, and clears the binding when it closes.
import SwiftUI

extension View {
    /// Shows `problem` as an alert with OK while it is non-nil; OK sets it back to nil.
    public func suiteProblemAlert(_ problem: Binding<String?>) -> some View {
        alert(
            problem.wrappedValue ?? "",
            isPresented: Binding(get: { problem.wrappedValue != nil }, set: { if !$0 { problem.wrappedValue = nil } })
        ) {
            Button("OK", role: .cancel) {}
        }
    }
}
