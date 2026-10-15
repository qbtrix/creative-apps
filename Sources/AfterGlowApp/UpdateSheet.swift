// UpdateSheet.swift: the update offer, a sheet on the home window. Not
// presented yet; the updater feature fills it (check, offer, progress,
// install and relaunch) and HomeWindow presents it.
import SuiteUI
import SwiftUI

struct UpdateSheet: View {
    var body: some View {
        Text("Updates arrive with the updater feature.")
            .font(SuiteFont.body)
            .foregroundStyle(SuiteColor.textSecondary)
            .padding(SuiteSpacing.xxl)
    }
}
