// SettingsView.swift: the launcher's Settings scene (AfterGlow > Settings…,
// Command-comma). For now one sentence; the settings feature adds General
// and one pane per app (blueprint suite.md 6.1).
import SuiteUI
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Text("Settings arrive with the settings feature.")
            .font(SuiteFont.body)
            .foregroundStyle(SuiteColor.textSecondary)
            .padding(SuiteSpacing.xxl)
    }
}
