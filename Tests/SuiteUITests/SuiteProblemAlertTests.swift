// SuiteProblemAlertTests.swift: SuiteUI's shared problem alert, read off the
// modifier `.suiteProblemAlert` builds rather than a live alert. The String form
// shows the string as the title with no message; the mapped form shows the
// caller's title and message; the OK keeps the id its caller passes; the alert
// is up while the problem is set, and OK (isPresented set to false) clears it.
// macOS only.
@testable import SuiteUI
import SwiftUI
import Testing

/// A problem the test can read back after the alert's binding writes it.
@MainActor
private final class Held<Value> {
    var value: Value?
    init(_ value: Value?) { self.value = value }
    var binding: Binding<Value?> { Binding(get: { self.value }, set: { self.value = $0 }) }
}

private struct FileProblem {
    let title: String
    let message: String
}

@MainActor @Suite struct SuiteProblemAlertTests {
    private func alert<P>(_ view: some View, _: P.Type) -> SuiteProblemAlert<P>? {
        func read<V: View>(_ view: V) -> SuiteProblemAlert<P>? {
            (view as? ModifiedContent<Text, SuiteProblemAlert<P>>)?.modifier
        }
        return read(view)
    }

    @Test func aStringProblemIsTheTitleWithNoMessage() throws {
        let held = Held("Poster.flare can't be opened.")
        let shown = try #require(alert(Text("").suiteProblemAlert(held.binding), String.self))
        #expect(shown.title == "Poster.flare can't be opened.")
        #expect(shown.message == nil)
        #expect(shown.okID == nil)
        #expect(shown.isPresented.wrappedValue)
    }

    @Test func aMappedProblemShowsItsTitleAndMessageAndKeepsTheOKID() throws {
        let held = Held(FileProblem(title: "Poster.design can't be saved.", message: "The disk is full."))
        let view = Text("").suiteProblemAlert(held.binding, title: { $0.title }, message: { $0.message }, okID: "design.problem.ok")
        let shown = try #require(alert(view, FileProblem.self))
        #expect(shown.title == "Poster.design can't be saved.")
        #expect(shown.message == "The disk is full.")
        #expect(shown.okID == "design.problem.ok")
    }

    @Test func noProblemShowsNoAlert() throws {
        let held = Held<String>(nil)
        let shown = try #require(alert(Text("").suiteProblemAlert(held.binding, okID: "suite.recovery.restoreError"), String.self))
        #expect(!shown.isPresented.wrappedValue)
        #expect(shown.title == "")
        #expect(shown.okID == "suite.recovery.restoreError")
        shown.isPresented.wrappedValue = true
        #expect(held.value == nil, "presenting with no problem invents none")
    }

    @Test func okClearsTheProblem() throws {
        let held = Held("The image can't be restored.")
        let shown = try #require(alert(Text("").suiteProblemAlert(held.binding), String.self))
        shown.isPresented.wrappedValue = true
        #expect(held.value == "The image can't be restored.", "only a close clears it")
        shown.isPresented.wrappedValue = false
        #expect(held.value == nil)
        #expect(!shown.isPresented.wrappedValue)
    }
}
