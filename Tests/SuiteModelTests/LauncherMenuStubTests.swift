// LauncherMenuStubTests.swift: the launcher's menus (blueprint suite.md 6.2)
// read as text, since SwiftUI doesn't build on Linux. Every item that is not
// the system's appears exactly once, in the stub of the feature that will
// build it, disabled with its not-connected reason and with its 6.2
// shortcut, except the home's, which LauncherCommandsHome renders from
// HomeMenu (HM-2c); AfterGlowApp.swift declares the three scenes and the
// command groups. Settings… ⌘, is the Settings scene's own item (it opens the
// placeholder), like About, Hide and Quit, so no stub declares it.
import Foundation
import SuiteModel
import Testing

private let commandFiles = [
    "Sources/AfterGlowApp/LauncherCommands+Home.swift",
    "Sources/AfterGlowApp/LauncherCommands+Assets.swift",
    "Sources/AfterGlowApp/LauncherCommands+Update.swift",
    "Sources/AfterGlowApp/LauncherCommands+Settings.swift",
    "Sources/SuiteShell/SuiteCommands.swift",
]

/// One 6.2 item: its title, the file that declares it, its feature and the
/// shortcut call that must follow it (nil when 6.2 gives none).
private struct Item {
    let title: String
    let file: String
    let feature: String
    var shortcut: String?
}

private func assets(_ title: String, _ shortcut: String? = nil) -> Item {
    Item(title: title, file: "LauncherCommands+Assets.swift", feature: "shared-assets", shortcut: shortcut)
}

private func switching(_ title: String, _ digit: Int) -> Item {
    Item(
        title: title, file: "SuiteCommands.swift", feature: "switching",
        shortcut: ".keyboardShortcut(\"\(digit)\", modifiers: [.control, .command])")
}

private let items: [Item] = [
    assets("Cut", ".keyboardShortcut(\"x\")"), assets("Copy", ".keyboardShortcut(\"c\")"),
    assets("Add from Clipboard", ".keyboardShortcut(\"v\")"), assets("Select All", ".keyboardShortcut(\"a\")"),
    assets("Assets", ".keyboardShortcut(\"a\", modifiers: [.option, .command])"),
    Item(title: "Check for Updates…", file: "LauncherCommands+Update.swift", feature: "updater"),
    switching("Home", 0), switching("Flare", 1), switching("Design", 2), switching("Photo", 3),
    switching("Library", 4), switching("Halo", 5),
]

private let homeFile = "Sources/AfterGlowApp/LauncherCommands+Home.swift"

/// Each HomeMenu item LauncherCommandsHome renders, and the 6.2 shortcut that must follow it.
private let homeFields: [(String, String?)] = [
    ("open", ".keyboardShortcut(\"o\")"), ("clearMenu", nil), ("undo", nil), ("delete", nil), ("showSidebar", nil),
    ("showInspector", ".keyboardShortcut(\"i\", modifiers: [.option, .command])"),
    ("larger", ".keyboardShortcut(\"+\")"), ("smaller", ".keyboardShortcut(\"-\")"),
]

/// The submenus, each declared once in its file.
private let menus = [
    ("New", "LauncherCommands+Home.swift"), ("Open Recent", "LauncherCommands+Home.swift"),
    ("Switch To", "SuiteCommands.swift"),
]

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

/// Each `Button(` statement of the file: the text from one `Button(` to the next.
private func buttons(_ text: String) -> [Substring] {
    text.components(separatedBy: "Button(").dropFirst().map { Substring($0) }
}

private func occurrences(of needle: String, in text: String) -> Int {
    text.components(separatedBy: needle).count - 1
}

@Suite struct LauncherMenuStubTests {
    @Test func everyItemOnceInItsFeaturesStub() throws {
        let texts = try Dictionary(uniqueKeysWithValues: commandFiles.map { ($0.split(separator: "/").last.map(String.init) ?? $0, try source($0)) })
        for item in items {
            let call = "Button(\"\(item.title)\")"
            let total = texts.values.reduce(0) { $0 + occurrences(of: call, in: $1) }
            #expect(total == 1, "\(item.title) is declared \(total) times")
            let text = try #require(texts[item.file], "\(item.file) is missing")
            let statement = buttons(text).first { $0.hasPrefix("\"\(item.title)\")") }
            let found = try #require(statement, "\(item.title) is not in \(item.file)")
            #expect(found.contains(".disabled(true)"), "\(item.title) is enabled")
            #expect(found.contains("notConnected(\"\(item.feature)\")"), "\(item.title) has no \(item.feature) reason")
            if let shortcut = item.shortcut {
                #expect(found.contains(shortcut), "\(item.title) lacks \(shortcut)")
            }
        }
        for (title, file) in menus {
            let total = texts.values.reduce(0) { $0 + occurrences(of: "Menu(\"\(title)\")", in: $1) }
            #expect(total == 1 && occurrences(of: "Menu(\"\(title)\")", in: texts[file] ?? "") == 1, "\(title) ▸")
        }
    }

    @Test func homeItemsComeFromHomeMenu() throws {
        let text = try source(homeFile)
        #expect(text.contains("@FocusedValue(\\.homeModel)") && text.contains("HomeMenu.make("))
        #expect(!text.contains("notConnected(") && !text.contains(".disabled(true)"))
        // Each item renders once, with its 6.2 shortcut.
        let statements = text.components(separatedBy: "HomeMenuItem(item: menu.").dropFirst()
        for (field, shortcut) in homeFields {
            let found = statements.filter { $0.hasPrefix(field + ")") }
            #expect(found.count == 1, "menu.\(field) renders \(found.count) times")
            if let shortcut { #expect(found.first?.contains(shortcut) == true, "menu.\(field) lacks \(shortcut)") }
        }
        #expect(text.contains("ForEach(menu.new,") && text.contains("ForEach(menu.recents,"))
        // The one Button: disabled, with its reason as help, whenever it can't act.
        let button = try #require(buttons(text).first)
        #expect(buttons(text).count == 1 && button.contains(".disabled(!item.isEnabled).help(item.reason"))
        let menu = HomeMenu.make(recents: RecentsList(), selection: nil, thumbnailStep: 1, page: .home, hasWindow: true)
        let titles = menu.new.map(\.item.title) + [menu.open, menu.clearMenu, menu.delete, menu.showSidebar,
                                                  menu.showInspector, menu.larger, menu.smaller].map(\.title)
        #expect(titles == ["New Animation", "New Design", "New Image", "Import Photos…", "New Composition", "Open…",
                           "Clear Menu", "Remove from Recents", "Show Sidebar", "Show Inspector",
                           "Larger Thumbnails", "Smaller Thumbnails"])
    }

    @Test func noItemEnabledWithoutAReason() throws {
        for file in commandFiles where file != homeFile {
            for statement in try buttons(source(file)) {
                #expect(statement.contains(".disabled(true)") && statement.contains("notConnected(\""), "\(file): \(statement)")
            }
        }
        // The system's own items are never declared again.
        let all = try commandFiles.map(source).joined(separator: "\n")
        for title in ["Settings…", "About AfterGlow", "Undo", "Redo", "Close", "Quit AfterGlow", "Delete", "Paste"] {
            #expect(!all.contains("Button(\"\(title)\")"), "\(title) is redeclared")
        }
    }

    @Test func appDeclaresTheScenesAndCommandGroups() throws {
        let app = try source("Sources/AfterGlowApp/AfterGlowApp.swift")
        for scene in ["Window(\"AfterGlow\", id: \"home\")", "Settings {", "Window(\"Welcome to AfterGlow\", id: \"onboarding\")"] {
            #expect(occurrences(of: scene, in: app) == 1, "\(scene)")
        }
        for group in [
            "SuiteCommands(app: .launcher)", "LauncherCommandsHome()", "LauncherCommandsAssets()",
            "LauncherCommandsUpdate()", "LauncherCommandsSettings()",
        ] {
            #expect(occurrences(of: group, in: app) == 1, "\(group)")
        }
        #expect(app.contains("@NSApplicationDelegateAdaptor(LauncherDelegate.self)"))
    }
}
