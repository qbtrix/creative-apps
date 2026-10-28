// OnboardingLauncherTests.swift: onboarding packet OB-3, read as text since
// SwiftUI doesn't build on Linux. AfterGlowApp.swift gives the onboarding
// scene its launch behavior, no restoration and its command group, each once,
// and keeps every scene and group LauncherMenuStubTests pins. Help > Welcome
// to AfterGlow (SuiteShell's Help group since report-problem RP-2) is live
// and opens the window; the window keeps the default
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
            "SuiteHelpCommands(app: .launcher)",
        ] {
            #expect(occurrences(of: line, in: app) == 1, "\(line)")
        }
        // The modifiers sit on the onboarding scene, after the home and Settings scenes.
        let scene = try #require(app.components(separatedBy: "Window(\"Welcome to AfterGlow\", id: \"onboarding\")").last)
        #expect(scene.contains(".defaultLaunchBehavior(") && scene.contains("SuiteHelpCommands(app: .launcher)"))
        // LauncherMenuStubTests' pinned strings stay, once each.
        for pinned in [
            "Window(\"AfterGlow\", id: \"home\")", "Settings {", "Window(\"Welcome to AfterGlow\", id: \"onboarding\")",
            "SuiteCommands(app: .launcher)", "LauncherCommandsHome()", "LauncherCommandsSettings()",
            "@NSApplicationDelegateAdaptor(LauncherDelegate.self)",
        ] {
            #expect(occurrences(of: pinned, in: app) == 1, "\(pinned)")
        }
    }

    /// A presented scene stops an `.automatic` one from presenting (Scene.defaultLaunchBehavior), so the
    /// home presents itself too, or Skip at first launch leaves no window. The welcome window is exactly
    /// OnboardingLayout's size: a `Window`'s automatic resizability is contentMinSize, which opened it
    /// 900 pt wide around the 720 pt content.
    @Test func homePresentsBesideTheWelcomeWindowAtItsOwnSize() throws {
        let app = try source("Sources/AfterGlowApp/AfterGlowApp.swift")
        let parts = app.components(separatedBy: "Window(\"Welcome to AfterGlow\", id: \"onboarding\")")
        let home = try #require(parts.first?.components(separatedBy: "Settings {").first)
        let scene = try #require(parts.last)
        #expect(home.contains(".defaultLaunchBehavior(.presented)"), "the home doesn't present at launch")
        #expect(scene.contains(".windowResizability(.contentSize)"), "the welcome window resizes past its content")
    }

    @Test func helpWelcomeIsLiveAndOpensTheWindow() throws {
        let text = try source("Sources/SuiteShell/SuiteHelpCommands.swift")
        #expect(occurrences(of: "openWindow(id: \"onboarding\")", in: text) == 1)
        #expect(text.contains("CommandGroup(replacing: .help)"))
        #expect(!text.contains("\"help.welcome\": \""), "Help > Welcome to AfterGlow is disabled")
    }

    @Test func windowKeepsShortcutsCounterAndCloseIsSkip() throws {
        let text = try source("Sources/AfterGlowApp/OnboardingWindow.swift")
        for needle in [
            "BodyCounted", "bodyTally.ran(Self.self)", ".keyboardShortcut(.defaultAction)", ".keyboardShortcut(.cancelAction)",
            "onDisappear", "model.skip()", "OnboardingControls.continue", "OnboardingControls.skip",
            "OnboardingControls.page", "LauncherServices.shared",
        ] {
            #expect(text.contains(needle), "OnboardingWindow lacks \(needle)")
        }
        let close = try #require(text.components(separatedBy: ".onDisappear").last)
        #expect(close.contains("model.skip()"), "closing the window doesn't skip")
    }

    /// OB-12: the window reads the bundle's Resources/Samples, copies into Documents and passes both on.
    @Test func windowReadsTheBundlesSamplesAndCopiesThem() throws {
        let router = try source("Sources/AfterGlowApp/LauncherRouter+Onboarding.swift")
        #expect(router.contains("static let samplesFolder = SampleCatalog.folder(resources: Bundle.main.resourcePath"),
                "samplesFolder isn't the bundle's Resources/Samples")
        #expect(router.contains("support + \"/Documents\""), "documents isn't the support folder's Documents")
        #expect(router.contains("copyItem(atPath: source, toPath: destination)"), "the copy doesn't copy")
        #expect(router.contains("withIntermediateDirectories: true"), "the copy doesn't make Documents/Samples")
        #expect(!router.contains("notAvailable"), "the copy still refuses")
        let window = try source("Sources/AfterGlowApp/OnboardingWindow.swift")
        for needle in [
            "samplesFolder: LauncherServices.samplesFolder", "documents: LauncherServices.documents(support: support)",
            "LauncherServices.copySample(source, to: destination)",
        ] {
            #expect(window.contains(needle), "OnboardingWindow lacks \(needle)")
        }
        #expect(!window.contains("notAvailable"), "the window's copy still refuses")
    }

    // OB-4: pages 2 and 3.
    static let windowFiles = [
        "Sources/AfterGlowApp/OnboardingWindow.swift", "Sources/AfterGlowApp/OnboardingPages.swift",
        "Sources/AfterGlowApp/OnboardingStartPage.swift", "Sources/SuiteShell/SuiteHelpCommands.swift",
    ]

    /// Every name OnboardingControls declares (`static let x` or `static func x(`), the prefix aside.
    private func declaredControls() throws -> [String] {
        let text = try source("Sources/SuiteModel/Onboarding/OnboardingStarter.swift")
        let body = try #require(text.components(separatedBy: "public enum OnboardingControls").last)
        return body.split(separator: "\n").compactMap { line -> String? in
            let words = line.split(whereSeparator: { " (:=`".contains($0) }).map(String.init)
            guard let at = words.firstIndex(where: { $0 == "let" || $0 == "func" }), words.contains("public"),
                  words.indices.contains(at + 1) else { return nil }
            return words[at + 1]
        }
    }

    @Test func everyOnboardingControlIsIdentified() throws {
        let names = try declaredControls()
        #expect(Set(names) == ["page", "continue", "back", "skip", "startEmpty", "help", "focus", "preset", "sample"])
        let text = try Self.windowFiles.map(source).joined(separator: "\n")
        for name in names {
            let ref = "OnboardingControls.\(name)"
            #expect(text.contains(ref) || text.contains("OnboardingControls.`\(name)`"), "no control uses \(ref)")
        }
        // The buttons publish to suite.controls; the chips carry theirs on each option (PresetGrid).
        for name in ["page", "continue", "back", "skip", "startEmpty", "sample("] {
            #expect(text.contains(".suiteControl(id: OnboardingControls.\(name)"), "\(name) isn't a suiteControl")
        }
        for name in ["focus($0)", "preset($0)"] {
            #expect(text.contains("identifier: OnboardingControls.\(name)"), "\(name) chips are unidentified")
        }
    }

    @Test func focusAndStartPagesUseChipsAndTitles() throws {
        let pages = try source("Sources/AfterGlowApp/OnboardingPages.swift")
        let start = try source("Sources/AfterGlowApp/OnboardingStartPage.swift")
        let window = try source("Sources/AfterGlowApp/OnboardingWindow.swift")
        #expect(pages.contains("ChoiceChips(") && start.contains("ChoiceChips("), "a page hand-rolls its chips")
        #expect(pages.contains("OnboardingStartPage(model:"), "page 3 isn't drawn")
        #expect(pages.contains("model.choose("), "a focus chip doesn't choose")
        #expect(start.contains("Button(\"Open sample\")") && start.contains("model.openSample("))
        #expect(start.contains("model.startNew("), "a preset chip doesn't create")
        #expect(window.contains("Button(\"Start from an empty home\")") && window.contains("model.finish()"))
        #expect(window.contains("Button(\"Back\") { model.back() }"))
    }

    @Test func skipAndBackHoldAndARefusalSitsUnderItsTile() throws {
        let window = try source("Sources/AfterGlowApp/OnboardingWindow.swift")
        for name in ["skip", "back"] {
            let call = ".suiteControl(id: OnboardingControls.\(name), enabled: model.sendingReason == nil, reason: model.sendingReason)"
            #expect(window.contains(call), "\(name) isn't held while a hand-off sends")
        }
        #expect(occurrences(of: ".disabled(model.sendingReason != nil)", in: window) == 2)
        // #3018: a held control's help is the model's, which says "A document is opening." while held.
        for help in [".help(model.skipHelp)", ".help(model.backHelp)", ".help(model.startEmptyHelp)"] {
            #expect(occurrences(of: help, in: window) == 1, "\(help)")
        }
        #expect(!window.contains("\"A document is opening.\""), "the window spells the hand-off's reason itself")
        let start = try source("Sources/AfterGlowApp/OnboardingStartPage.swift")
        #expect(start.contains(".help(model.presetsHelp(tile))") && start.contains(".help(model.sampleHelp(starter))"))
        #expect(!start.contains("at once"), "a chip's help still says at once")
        let pages = try source("Sources/AfterGlowApp/OnboardingPages.swift")
        #expect(pages.contains("title: SuiteOnboarding.focusTitle($0)"), "a focus chip doesn't name its apps")
        #expect(start.contains("if model.failed == starter.tile.app, let message = model.message"), "a refusal isn't under its tile")
        #expect(start.contains("if model.failed == nil, let message = model.message"))
    }

    @Test func pagesUseNoLiteralSizes() throws {
        for path in Self.windowFiles {
            let text = try source(path)
            for modifier in ["frame(", "padding(", "spacing: ", "Spacing: "] {
                for part in text.components(separatedBy: modifier).dropFirst() {
                    let next = part.drop(while: { $0 == " " || $0 == "." }).first
                    #expect(!(next?.isNumber ?? false), "\(path): a literal after \(modifier)")
                    let inner = part.prefix(while: { $0 != ")" })
                    #expect(!inner.contains(where: \.isNumber) || inner.contains("Spacing") || inner.contains("Size")
                        || inner.contains("Layout"), "\(path): \(modifier)\(inner)")
                }
            }
        }
    }
}
