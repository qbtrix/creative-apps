// SuiteAlerts.swift: the problem alert every app shows the same way. A failed
// open or save, or a refused edit, shows as one system alert: the problem's
// title, an optional message under it, and a single OK (cancel role, so Return
// and Escape both close it) that sets the caller's problem back to nil.
// A caller that keeps its problem as one sentence uses the String form; one
// with a title and a message (Design's DesignFileProblem, Photo's PhotoProblem)
// maps them at the call site, so the problem types stay where they live.
// `okID` is the OK button's accessibility id, for callers whose journeys press
// it by id. Presenting with no problem set never invents one.
import SwiftUI

/// The modifier behind `.suiteProblemAlert`; its values are what the alert shows.
public struct SuiteProblemAlert<Problem>: ViewModifier {
    let problem: Binding<Problem?>
    let titleOf: (Problem) -> String
    let messageOf: (Problem) -> String?
    let okID: String?

    /// The alert's title: the current problem's, or empty while there is none.
    var title: String { problem.wrappedValue.map(titleOf) ?? "" }
    /// The line under the title, if the problem has one.
    var message: String? { problem.wrappedValue.flatMap(messageOf) }
    /// Up while a problem is set; closing it (OK) clears the problem.
    var isPresented: Binding<Bool> {
        Binding(get: { problem.wrappedValue != nil }, set: { if !$0 { problem.wrappedValue = nil } })
    }

    public func body(content: Content) -> some View {
        content.alert(title, isPresented: isPresented) {
            if let okID {
                Button("OK", role: .cancel) {}.accessibilityIdentifier(okID)
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            if let message { Text(message) }
        }
    }
}

extension View {
    /// Shows `problem` as an alert while it is set: `title(problem)` with `message(problem)` under it and one OK
    /// (accessibility id `okID`) that sets it back to nil.
    public func suiteProblemAlert<Problem>(
        _ problem: Binding<Problem?>, title: @escaping (Problem) -> String,
        message: @escaping (Problem) -> String? = { _ in nil }, okID: String? = nil
    ) -> some View {
        modifier(SuiteProblemAlert(problem: problem, titleOf: title, messageOf: message, okID: okID))
    }

    /// Shows `problem` as the alert's title while it is set, with one OK that sets it back to nil.
    public func suiteProblemAlert(_ problem: Binding<String?>, okID: String? = nil) -> some View {
        suiteProblemAlert(problem, title: { $0 }, okID: okID)
    }
}
