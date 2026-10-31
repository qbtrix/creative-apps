// OnboardingWindow.swift: the "Welcome to AfterGlow" window (onboarding
// packet OB-3): an OnboardingModel on LauncherServices.shared, the page it
// shows (OnboardingPages.swift) and Skip, Back (after page 1) and Continue
// at the bottom, held with the model's reason while a hand-off sends; on the last page "Start from an empty home" (OB-4) takes
// Continue's place as the default button. All of it sits on
// OnboardingLayout's size and 24 pt margin. The scene presents itself at
// launch when `launchBehavior` says so (OnboardingLaunch, decided once,
// before the first frame) and Help > Welcome to AfterGlow reopens it, on
// page 1 again: the scene keeps its state, so `onAppear` calls `model.reopen()`.
// Closing the window is Skip: `onDisappear` without a finish calls
// `model.skip()`. `init(model:)` lets the snapshot and render budget suites
// show a model they drove. The page id rides a ProbeElement's label, which
// XCUITest can read (#262). The view only reads the model and calls its methods.
import Foundation
import SuiteModel
import SuiteUI
import SwiftUI

struct OnboardingWindow: View, BodyCounted {
    @State private var model: OnboardingModel
    @Environment(\.dismissWindow) private var dismissWindow

    /// Presented at launch unless `-SuiteSkipOnboarding YES` or the stored preferences say it was done.
    static let launchBehavior: SceneLaunchBehavior = OnboardingLaunch.presents(
        arguments: ProcessInfo.processInfo.arguments,
        stored: OnboardingLaunch.stored(in: FileStore(folder: LauncherServices.support)),
        flow: LauncherServices.shared.onboarding) ? .presented : .suppressed

    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    init(services: SuiteServices = LauncherServices.shared, support: String = LauncherServices.support) {
        // The bundle's samples, the support folder's Documents and the copy (LauncherRouter+Onboarding).
        _model = State(initialValue: OnboardingModel(
            services: services, samplesFolder: LauncherServices.samplesFolder,
            documents: LauncherServices.documents(support: support), present: { FileManager.default.fileExists(atPath: $0) },
            copy: { source, destination throws(SuiteError) in try LauncherServices.copySample(source, to: destination) }))
    }

    /// The window over a given model: AfterGlowOnboardingSnapshots shoots a page or state it put the model in.
    init(model: OnboardingModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            OnboardingPageView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityElement(children: .contain)
                // XCUITest reads SwiftUI values as empty (#262): the page id travels as the probe's label.
                .background { ProbeElement(OnboardingControls.page, label: model.page.id, value: model.page.id) }
                .suiteControl(id: OnboardingControls.page, enabled: true, reason: nil, role: "page", identifies: false)
            HStack(spacing: SuiteSpacing.m) {
                Button("Skip") { Task { await model.skip() } }
                    .keyboardShortcut(.cancelAction)
                    .help(model.skipHelp)
                    .disabled(model.sendingReason != nil)
                    .suiteControl(id: OnboardingControls.skip, enabled: model.sendingReason == nil, reason: model.sendingReason)
                Spacer()
                if model.canGoBack {
                    Button("Back") { model.back() }
                        .help(model.backHelp)
                        .disabled(model.sendingReason != nil)
                        .suiteControl(id: OnboardingControls.back, enabled: model.sendingReason == nil, reason: model.sendingReason)
                }
                if model.isLastPage {
                    // The start page's way out with nothing opened: finishes with the chosen focus.
                    Button("Start from an empty home") { Task { await model.finish() } }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .help(model.startEmptyHelp)
                        .disabled(model.launching != nil)
                        .suiteControl(id: OnboardingControls.startEmpty, enabled: model.launching == nil,
                                      reason: model.sendingReason)
                } else {
                    Button("Continue") { model.continue() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .suiteControl(id: OnboardingControls.continue, enabled: true, reason: nil)
                }
            }
        }
        .padding(CGFloat(OnboardingLayout.margin))
        .frame(width: CGFloat(OnboardingLayout.width), height: CGFloat(OnboardingLayout.height))
        .suiteProbes()
        .onAppear { model.reopen() }
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
