// CopyButton.swift: the suite's Copy button. It runs its action, then reads "Copied" with a checkmark for
// 1.5 s, so a copy that only touches the pasteboard still shows it happened. The Copied state is its own,
// so a press runs no body of the view around it.
import SwiftUI

/// "Copy" that runs `action` and confirms it with "Copied" for a moment.
public struct CopyButton: View {
    private let action: @MainActor () -> Void
    @State private var copied = false
    @State private var reset: Task<Void, Never>?

    public init(action: @escaping @MainActor () -> Void) { self.action = action }

    public var body: some View {
        Button {
            action()
            copied = true
            reset?.cancel()
            reset = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                if !Task.isCancelled { copied = false }
            }
        } label: {
            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                .labelStyle(.titleAndIcon).contentTransition(.symbolEffect(.replace))
        }
    }
}
