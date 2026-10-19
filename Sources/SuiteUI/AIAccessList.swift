// AIAccessList.swift (afterglow-mcp MC-12): Window > AI Access…'s body, one row per
// remembered grant (client, app, decision) with Revoke, or an empty state.
import SuiteModel
import SwiftUI

/// The remembered grants, each revocable.
public struct AIAccessList: View {
    private let entries: [AIAccessEntry]
    private let onRevoke: @MainActor (AIAccessEntry) -> Void

    public init(entries: [AIAccessEntry], onRevoke: @escaping @MainActor (AIAccessEntry) -> Void) {
        self.entries = entries
        self.onRevoke = onRevoke
    }

    public var body: some View {
        Group {
            if entries.isEmpty {
                EmptyStateView(AIAccessPrompt.emptyTitle, systemImage: "sparkles", message: AIAccessPrompt.emptyMessage)
            } else {
                List(entries, id: \.self) { entry in
                    HStack(spacing: SuiteSpacing.m) {
                        VStack(alignment: .leading, spacing: SuiteSpacing.xxs) {
                            Text(entry.client).font(SuiteFont.body)
                            Text("\(entry.app) · \(AIAccessPrompt.status(entry.decision))")
                                .font(SuiteFont.caption).foregroundStyle(SuiteColor.textSecondary)
                        }
                        Spacer()
                        Button(AIAccessPrompt.revoke) { onRevoke(entry) }
                            .accessibilityIdentifier("suite.aiaccess.revoke.\(entry.client)")
                    }
                }
            }
        }
        .frame(minWidth: SuiteSize.contentMinimum.width, minHeight: SuiteSize.contentMinimum.height)
        .accessibilityIdentifier("suite.aiaccess.list")
    }
}
