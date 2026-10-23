// AssistantConnectSheet.swift (cli-bundle CB-5): Help > Connect an AI Assistant…'s sheet. A stub: the next commit
// draws the command, the JSON block and their buttons.
import SuiteModel
import SwiftUI

/// The Connect an AI Assistant sheet over `panel`.
public struct AssistantConnectSheet: View {
    nonisolated static let controls = ["command", "copyCommand", "config", "copyConfig", "install", "aiAccess", "close"]
    nonisolated static func identifier(_ control: String) -> String { "suite.help.connect." + control }

    public init(
        panel: AssistantConnectPanel, onCopy: @escaping @MainActor (String) -> Void, onInstall: (@MainActor () -> Void)? = nil,
        onOpenAIAccess: @escaping @MainActor () -> Void, onClose: @escaping @MainActor () -> Void
    ) {}

    public var body: some View { EmptyView() }
}
