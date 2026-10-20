// AIAccessSheet.swift (afterglow-mcp MC-12): the sheet shown when an MCP client asks to
// drive a window: Deny (Escape), Always Allow and Allow Once (Return).
import SuiteModel
import SwiftUI

/// Asks whether `request`'s client may drive this app, and reports the answer.
public struct AIAccessSheet: View {
    private let request: AIAccessRequest
    private let onDecide: @MainActor (AIAccessDecision) -> Void

    public init(request: AIAccessRequest, onDecide: @escaping @MainActor (AIAccessDecision) -> Void) {
        self.request = request
        self.onDecide = onDecide
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            Label {
                VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                    Text(AIAccessPrompt.title(request)).font(SuiteFont.headline)
                    Text(AIAccessPrompt.message(request)).font(SuiteFont.body)
                        .foregroundStyle(SuiteColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(AIAccessPrompt.choiceHelp(request)).font(SuiteFont.caption)
                        .foregroundStyle(SuiteColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "sparkles").font(SuiteFont.title).foregroundStyle(SuiteColor.accent)
            }
            HStack(spacing: SuiteSpacing.s) {
                Button(AIAccessPrompt.deny, role: .cancel) { onDecide(.deny) }
                    .keyboardShortcut(.cancelAction).accessibilityIdentifier("suite.aiaccess.deny")
                Spacer()
                Button(AIAccessPrompt.alwaysAllow) { onDecide(.alwaysForClient) }.accessibilityIdentifier("suite.aiaccess.always")
                Button(AIAccessPrompt.allowOnce) { onDecide(.allowOnce) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("suite.aiaccess.allowOnce")
            }
        }
        .padding(SuiteSpacing.xl)
        .frame(width: SuiteSize.contentMinimum.width)
        .accessibilityIdentifier("suite.aiaccess.sheet")
    }
}
