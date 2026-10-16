// HomeRunningStrip.swift: one line under the recents: the running apps, "No
// apps running", or "Opening <App>…" with a ring while `launching` is set
// (ProgressRow #781 replaces it; per-app switch buttons come with switching).
import SuiteModel
import SuiteUI
import SwiftUI

struct HomeRunningStrip: View {
    let model: HomeModel

    var body: some View {
        HStack(spacing: SuiteSpacing.s) {
            Text("RUNNING").font(SuiteFont.sectionCaps)
            if model.launching != nil { ProgressView().controlSize(.small) }
            Text(model.launching.map { "Opening \($0.displayName)…" }
                 ?? (model.state.running.isEmpty ? "No apps running"
                     : model.state.running.map(\.displayName).joined(separator: ", ")))
        }
        .font(SuiteFont.body)
        .foregroundStyle(SuiteColor.textSecondary)
    }
}
