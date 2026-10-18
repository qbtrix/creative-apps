// OnboardingLauncherTests.swift: onboarding packet OB-3, read as text since
// SwiftUI doesn't build on Linux. AfterGlowApp.swift gives the onboarding
// scene its launch behavior, no restoration and its command group, each once,
// and keeps every scene and group LauncherMenuStubTests pins. Help > Welcome
// to AfterGlow is live and opens the window; the window keeps the default
// and cancel shortcuts, the body counter and close-means-Skip.
import Foundation
import Testing

/// The package root: the first folder above this file that holds Package.swift.
private func packageRoot() -> URL? {
    var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while dir.path != "/" {
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
        dir = dir.deletingLastPathComponent()
    }
    return nil
}

/// The file's text without its comment lines.
private func source(_ path: String) throws -> String {
    let root = try #require(packageRoot())
    let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    return text.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n")
}

private func occurrences(of needle: String, in text: String) -> Int {
    text.components(separatedBy: needle).count - 1
}

@Suite struct OnboardingLauncherTests {
    @Test func appGivesTheOnboardingSceneItsBehaviorOnce() throws {
        let app = try source("Sources/AfterGlowApp/AfterGlowApp.swift")
        for line in [
            ".defaultLaunchBehavior(OnboardingWindow.launchBehavior)", ".restorationBehavior(.disabled)",
            "LauncherCommandsOnboarding()",
        ] {
            #expect(occurrences(of: line, in: app) == 1, "\(line)")
        }
        // The modifiers sit on the onboarding scene, after the home and Settings scenes.
        let scene = try #require(app.components(separatedBy: "Window(\"Welcome to AfterGlow\", id: \"onboarding\")").last)
        #expect(scene.contains(".defaultLaunchBehavior(") && scene.contains("LauncherCommandsOnboarding()"))
        // LauncherMenuStubTests' pinned strings stay, once each.
        for pinned in [
            "Window(\"AfterGlow\", id: \"home\")", "Settings {", "Window(\"Welcome to AfterGlow\", id: \"onboarding\")",
            "SuiteCommands(app: .launcher)", "LauncherCommandsHome()", "LauncherCommandsAssets()",
            "LauncherCommandsUpdate()", "LauncherCommandsSettings()", "@NSApplicationDelegateAdaptor(LauncherDelegate.self)",
        ] {
            #expect(occurrences(of: pinned, in: app) == 1, "\(pinned)")
        }
    }

    @Test func helpWelcomeIsLiveAndOpensTheWindow() throws {
        let text = try source("Sources/AfterGlowApp/LauncherCommands+Onboarding.swift")
        #expect(occurrences(of: "Button(\"Welcome to AfterGlow\")", in: text) == 1)
        #expect(text.contains("openWindow(id: \"onboarding\")"))
        #expect(text.contains("CommandGroup(after: .help)"))
        #expect(!text.contains(".disabled("), "Help > Welcome to AfterGlow is disabled")
    }

    @Test func windowKeepsShortcutsCounterAndCloseIsSkip() throws {
        let text = try source("Sources/AfterGlowApp/OnboardingWindow.swift")
        for needle in [
            "static var bodyRuns", ".keyboardShortcut(.defaultAction)", ".keyboardShortcut(.cancelAction)",
            "onDisappear", "model.skip()", "OnboardingControls.continue", "OnboardingControls.skip",
            "OnboardingControls.page", "LauncherServices.shared",
        ] {
            #expect(text.contains(needle), "OnboardingWindow lacks \(needle)")
        }
        let close = try #require(text.components(separatedBy: ".onDisappear").last)
        #expect(close.contains("model.skip()"), "closing the window doesn't skip")
    }
}
