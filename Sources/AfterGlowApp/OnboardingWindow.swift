// OnboardingWindow.swift: the "Welcome to AfterGlow" window (onboarding
// packet OB-3): an OnboardingModel on LauncherServices.shared, the page it
// shows (OnboardingPages.swift) and Skip and Continue at the bottom, on
// OnboardingLayout's size and 24 pt margin. The scene presents itself at
// launch when `launchBehavior` says so (OnboardingLaunch, decided once,
// before the first frame) and Help > Welcome to AfterGlow reopens it.
// Closing the window is Skip: `onDisappear` without a finish calls
// `model.skip()`. The view only reads the model and calls its methods.
import Foundation
import SuiteModel
import SuiteUI
import SwiftUI

struct OnboardingWindow: View {
    @State private var model: OnboardingModel
    @Environment(\.dismissWindow) private var dismissWindow

    /// Presented at launch unless `-SuiteSkipOnboarding YES` or the stored preferences say it was done.
    static let launchBehavior: SceneLaunchBehavior = OnboardingLaunch.presents(
        arguments: ProcessInfo.processInfo.arguments,
        stored: OnboardingLaunch.stored(in: FileStore(folder: LauncherServices.support)),
        flow: LauncherServices.shared.onboarding) ? .presented : .suppressed

    #if DEBUG
    /// How many times the window's body ran; RenderBudgetAfterGlowOnboardingTests counts an interaction's.
    // view-static: main-actor
    static var bodyRuns = 0
    #endif

    init(services: SuiteServices = LauncherServices.shared, support: String = LauncherServices.support) {
        // The samples folder and the copy are wired by OB-12; until then Open sample can't copy.
        _model = State(initialValue: OnboardingModel(
            services: services, samplesFolder: SampleCatalog.folder(resources: Bundle.main.resourcePath ?? ""),
            documents: support + "/Documents", present: { FileManager.default.fileExists(atPath: $0) },
            copy: { _, _ throws(SuiteError) in throw SuiteError.notAvailable("Samples arrive with the onboarding feature.") }))
    }

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            OnboardingPageView(page: model.page, renderingNote: model.renderingNote)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityElement(children: .contain)
                .accessibilityValue(model.page.id)
                .suiteControl(id: OnboardingControls.page, enabled: true, reason: nil, role: "page")
            HStack(spacing: SuiteSpacing.m) {
                Button("Skip") { Task { await model.skip() } }
                    .keyboardShortcut(.cancelAction)
                    .help("Close the welcome window. Help > Welcome to AfterGlow opens it again.")
                    .suiteControl(id: OnboardingControls.skip, enabled: true, reason: nil)
                Spacer()
                Button("Continue") { model.continue() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .suiteControl(id: OnboardingControls.continue, enabled: true, reason: nil)
            }
        }
        .padding(CGFloat(OnboardingLayout.margin))
        .frame(width: CGFloat(OnboardingLayout.width), height: CGFloat(OnboardingLayout.height))
        .suiteProbes()
        .task { await model.load() }
        .onChange(of: model.isFinished) { _, finished in
            if finished { dismissWindow(id: "onboarding") }
        }
        .onDisappear {
            // Closing the window is Skip (the HIG: onboarding is never a trap).
            if !model.isFinished { Task { await model.skip() } }
        }
    }
}
