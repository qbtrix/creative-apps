// SuiteAIAccessSnapshots.swift (afterglow-mcp MC-12): suite-ai-access-sheet, -chip, -list
// (one grant) and -list-empty, each -light and -dark.
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteAIAccessSnapshots {
    private let request = AIAccessRequest(client: FakeAIAccess.demoClient, app: "Photo", command: "photo.crop")
    private let grant = AIAccessEntry(client: FakeAIAccess.demoClient, app: "Photo", decision: .alwaysForClient)

    @Test func sheetChipAndList() throws {
        for (scheme, suffix) in [(ColorScheme.light, "light"), (.dark, "dark")] {
            try snapshot(AIAccessStage { AIAccessSheet(request: request) { _ in } }, name: "suite-ai-access-sheet-\(suffix)", scheme: scheme)
            try snapshot(AIAccessStage { AIAccessChip(client: FakeAIAccess.demoClient) {} }, name: "suite-ai-access-chip-\(suffix)", scheme: scheme)
            try snapshot(AIAccessStage { AIAccessList(entries: [grant]) { _ in } }, name: "suite-ai-access-list-\(suffix)", scheme: scheme)
            try snapshot(AIAccessStage { AIAccessList(entries: []) { _ in } }, name: "suite-ai-access-list-empty-\(suffix)", scheme: scheme)
        }
    }
}

/// One AI access view on a panel at the top left of the 1440x900 frame.
private struct AIAccessStage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
