// AssetsPage.swift: the shared asset and colour library, a page of the home
// window's sidebar. Not shown yet; the shared-assets feature builds it and
// wires Window > Assets and the Edit items in LauncherCommands+Assets.swift.
import SuiteUI
import SwiftUI

struct AssetsPage: View {
    var body: some View {
        Text("Shared assets arrive with the shared-assets feature.")
            .font(SuiteFont.body)
            .foregroundStyle(SuiteColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
