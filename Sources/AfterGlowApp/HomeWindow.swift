// HomeWindow.swift: the launcher's home window. For now one centered
// sentence; the home feature replaces it with the new tiles, recents and
// running apps (blueprint suite.md 6.1) and presents UpdateSheet.
import SuiteUI
import SwiftUI

struct HomeWindow: View {
    var body: some View {
        Text("The AfterGlow home arrives with the home feature.")
            .font(SuiteFont.body)
            .foregroundStyle(SuiteColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The minimum SuiteWindow's apps use.
            .frame(minWidth: SuiteSize.windowMinimum.width, minHeight: SuiteSize.windowMinimum.height)
    }
}
