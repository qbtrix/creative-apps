// AIAccessChip.swift (afterglow-mcp MC-12): "Controlled by <client>" with Stop, in the title
// bar while an MCP client drives the window; the tint pairs with a symbol.
import SuiteModel
import SwiftUI

/// The title-bar chip that says which client is in control, with Stop.
public struct AIAccessChip: View {
    private let client: String
    private let onStop: @MainActor () -> Void

    public init(client: String, onStop: @escaping @MainActor () -> Void) {
        self.client = client
        self.onStop = onStop
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.s) {
            Label(AIAccessPrompt.chip(client: client), systemImage: "sparkles")
                .font(SuiteFont.pill)
                .foregroundStyle(SuiteColor.textPrimary)
                .accessibilityIdentifier("suite.aiaccess.chip")
            Button(AIAccessPrompt.stop, systemImage: "stop.fill") { onStop() }
                .controlSize(SuiteSize.compactControl)
                .help("Stop \(client) from controlling this window")
                .accessibilityIdentifier("suite.aiaccess.stop")
        }
        .padding(SuiteInset.pill)
        .frame(minHeight: SuiteSize.chip)
        .background(SuiteColor.warningTint, in: Capsule())
        .accessibilityElement(children: .contain)
    }
}
