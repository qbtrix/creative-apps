// SuiteCommandsTests.swift: the Window > Switch To menu (SW-3c; blueprint 6.2),
// read as text since SwiftUI doesn't build on Linux. The items come from
// SwitchMenu, so each is enabled exactly when the switcher's is, and no other
// file in an app or the shell claims a Control-Command shortcut.
import Foundation
import Testing

@Suite struct SuiteCommandsTests {
    @Test func switchToBuildsItsItemsFromTheMenuModel() throws {
        let text = try source("Sources/SuiteShell/SuiteCommands.swift")
        #expect(text.contains("SwitchMenu.items(current: app, states: runStates())"))
        #expect(text.contains(".disabled(!item.enabled)") && text.contains(".help(item.reason ?? \"\")"))
        #expect(text.contains("modifiers: [.control, .command]"))
        #expect(!text.contains("notConnected("))
    }

    @Test func noOtherFileClaimsAControlCommandShortcut() throws {
        let root = try #require(packageRoot())
        let fm = FileManager.default
        let folders = try fm.contentsOfDirectory(atPath: root.appendingPathComponent("Sources").path)
            .filter { $0.hasSuffix("App") || $0 == "SuiteShell" }
        for folder in folders {
            let url = root.appendingPathComponent("Sources/\(folder)")
            for file in try fm.contentsOfDirectory(atPath: url.path) where file.hasSuffix(".swift") && file != "SuiteCommands.swift" {
                let text = try String(contentsOf: url.appendingPathComponent(file), encoding: .utf8)
                for line in text.split(separator: "\n") where line.contains(".keyboardShortcut(") {
                    let claimed = line.contains(".control") && line.contains(".command")
                    #expect(!claimed, "\(folder)/\(file) claims a Control-Command shortcut: \(line)")
                }
            }
        }
    }

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
}
