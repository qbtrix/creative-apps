// OnboardingPages.swift: the welcome window's pages (onboarding packet).
// Page 1, "apps" (OB-3): the title, the five apps' marks (AppMark's line
// form, as the home's sidebar rows and New tiles draw them) with their
// names, the page's body and the one Rendering line. Page 2, "focus" (OB-4):
// the page's focuses as ChoiceChips, none selected until a click, a second
// click on the same chip clears it. Page 3, "start" (OB-4): the starter row
// (OnboardingStartPage.swift). The pages read the model and call its methods.
import SuiteModel
import SuiteUI
import SwiftUI

struct OnboardingPageView: View {
    let model: OnboardingModel

    var body: some View {
        let page = model.page
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            Text(page.title).font(SuiteFont.title).foregroundStyle(SuiteColor.textPrimary)
            if page.id == "apps" { OnboardingAppsRow() }
            Text(page.body).font(SuiteFont.body).foregroundStyle(SuiteColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            switch page.id {
            case "apps":
                Text(model.renderingNote).font(SuiteFont.caption).foregroundStyle(SuiteColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            case "focus":
                OnboardingFocusChips(model: model, choices: page.choices)
            case "start":
                OnboardingStartPage(model: model)
            default:
                EmptyView()
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

/// "What do you make most?": one chip per focus, each with its own identifier; optional, so Continue stays on.
private struct OnboardingFocusChips: View {
    let model: OnboardingModel
    let choices: [OnboardingFocus]

    var body: some View {
        let options = choices.map {
            InspectorOption(id: $0, title: SuiteOnboarding.focusTitle($0), identifier: OnboardingControls.focus($0))
        }
        ChoiceChips(options: options, selected: model.focus) { model.choose($0) }
            .help("Puts the apps you use most first, here and on the home.")
    }
}
