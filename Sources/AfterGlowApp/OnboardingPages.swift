// OnboardingPages.swift: the welcome window's pages (onboarding packet).
// OB-3 draws page 1, "apps": the title, the five apps' marks (AppMark's
// line form, as the home's sidebar rows and New tiles draw them) with their
// names, the page's body and the one Rendering line. The other pages show
// their title and body until OB-4 adds the focus chips and the starter row.
import SuiteModel
import SuiteUI
import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    let renderingNote: String

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            Text(page.title).font(SuiteFont.title).foregroundStyle(SuiteColor.textPrimary)
            if page.id == "apps" { OnboardingAppsRow() }
            Text(page.body).font(SuiteFont.body).foregroundStyle(SuiteColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if page.id == "apps" {
                Text(renderingNote).font(SuiteFont.caption).foregroundStyle(SuiteColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The five apps in suite order, each its mark over its name.
private struct OnboardingAppsRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xl) {
            ForEach(SuiteApp.apps, id: \.self) { app in
                VStack(spacing: SuiteSpacing.xs) {
                    AppMark(app: app, style: .line).symbolSized().font(SuiteFont.title)
                        .frame(height: SuiteSize.switcherIcon)
                    Text(app.displayName).font(SuiteFont.caption).foregroundStyle(SuiteColor.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
