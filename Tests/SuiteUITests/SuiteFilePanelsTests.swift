// SuiteFilePanelsTests.swift: the suite's one file panel API (#5081) without a real panel. Each app's Open types
// come from SuiteTypeRegistry, a save name gets its extension, the last folder is remembered per app's defaults
// (an explicit start folder wins), the `answer` seam and `-SuiteFilePanelAnswer` stand in for the panel, and no
// file outside SuiteFilePanels.swift builds an NSOpenPanel or NSSavePanel. macOS only.
import Foundation
import SuiteModel
@testable import SuiteUI
import Testing
import UniformTypeIdentifiers

@MainActor @Suite(.serialized) struct SuiteFilePanelsTests {
    /// A fresh defaults domain, so no test writes the real one.
    private func scratch() -> UserDefaults {
        let name = "SuiteFilePanelsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Runs `body` with the seam answering `urls` and recording each request; both restored after.
    private func answering(_ urls: [URL]?, _ body: () -> Void) -> [SuiteFilePanels.Request] {
        var seen: [SuiteFilePanels.Request] = []
        let defaults = SuiteFilePanels.defaults
        SuiteFilePanels.defaults = scratch()
        SuiteFilePanels.answer = { seen.append($0); return urls }
        defer { SuiteFilePanels.answer = nil; SuiteFilePanels.defaults = defaults }
        body()
        return seen
    }

    @Test func photoOpensEveryRegistryImageAndItsDocument() {
        let types = Set(SuiteFilePanels.openTypes(for: .photo))
        #expect(types.contains(UTType(filenameExtension: "ora")!))
        for format in SuiteImageFormats.all {
            for ext in format.extensions { #expect(types.contains(UTType(filenameExtension: ext)!), "\(ext)") }
        }
    }

    @Test func eachAppOpensOnlyWhatTheRegistryGivesIt() {
        #expect(SuiteFilePanels.openTypes(for: .design) == [UTType(filenameExtension: "design")!])
        #expect(SuiteFilePanels.openTypes(for: .flare, adding: ["json"])
            == [UTType(filenameExtension: "flare")!, UTType(filenameExtension: "json")!])
        #expect(!SuiteFilePanels.openTypes(for: .library).contains(UTType(filenameExtension: "ora")!))
    }

    @Test func saveNamesGetTheirExtensionOnce() {
        #expect(SuiteFilePanels.fileName(nil, extension: "design") == "Untitled.design")
        #expect(SuiteFilePanels.fileName("", extension: "design") == "Untitled.design")
        #expect(SuiteFilePanels.fileName("Logo", extension: "flare") == "Logo.flare")
        #expect(SuiteFilePanels.fileName("Logo.FLARE", extension: "flare") == "Logo.FLARE")
    }

    @Test func theSeamAnswersEveryKindWithoutAPanel() {
        let file = URL(fileURLWithPath: "/tmp/a/Logo.flare"), folder = URL(fileURLWithPath: "/tmp/out", isDirectory: true)
        var opened: URL?, saved: URL?
        let seen = answering([file]) {
            opened = SuiteFilePanels.chooseFile(types: [.png])
            saved = SuiteFilePanels.chooseSaveURL(named: "Logo.flare", types: [.png])
        }
        #expect(opened == file && saved == file)
        #expect(seen.map(\.kind) == [.open, .save])
        #expect(seen[0].types == [.png] && !seen[0].multiple && seen[0].prompt == "Open")
        #expect(seen[1].name == "Logo.flare" && seen[1].prompt == "Save")
        var chosen: URL?
        let asked = answering([folder]) { chosen = SuiteFilePanels.chooseFolder(prompt: "Export") }
        #expect(chosen == folder && asked.map(\.kind) == [.folder] && asked[0].prompt == "Export")
        var cancelled: [URL] = [file]
        _ = answering(nil) { cancelled = SuiteFilePanels.chooseFiles(types: [], multiple: true) }
        #expect(cancelled.isEmpty)
    }

    @Test func theLastFolderIsRememberedAndAnExplicitOneWins() {
        let file = URL(fileURLWithPath: "/tmp/photos/a.png"), given = URL(fileURLWithPath: "/tmp/given", isDirectory: true)
        let seen = answering([file]) {
            _ = SuiteFilePanels.chooseFile(types: [.png])
            _ = SuiteFilePanels.chooseFolder()
            _ = SuiteFilePanels.chooseFolder(directory: given)
        }
        #expect(seen[0].directory == nil)
        #expect(seen[1].directory?.path == "/tmp/photos")
        #expect(seen[2].directory == given)
        let folder = URL(fileURLWithPath: "/tmp/out", isDirectory: true)
        let after = answering([folder]) { _ = SuiteFilePanels.chooseFolder(); _ = SuiteFilePanels.chooseFolder() }
        #expect(after[1].directory?.path == "/tmp/out")
    }

    @Test func theLaunchArgumentAnswersOrCancels() {
        let defaults = scratch()
        #expect(SuiteFilePanels.launchAnswer(defaults) == nil)
        defaults.set("/tmp/x/Logo.flare", forKey: "SuiteFilePanelAnswer")
        #expect(SuiteFilePanels.launchAnswer(defaults) == [URL(fileURLWithPath: "/tmp/x/Logo.flare")])
        defaults.set("", forKey: "SuiteFilePanelAnswer")
        #expect(SuiteFilePanels.launchAnswer(defaults) == [])
    }

    /// Files that still build their own panel; shrink only. Library's import panel waits on #4924 and #4949.
    static let unmoved: Set<String> = [
        "Sources/LibraryApp/LibraryWindow+Import.swift",
    ]

    @Test func noOtherFileBuildsAPanel() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let base = root.appendingPathComponent("Sources")
        var builders: Set<String> = []
        for path in FileManager.default.enumerator(atPath: base.path)?.compactMap({ $0 as? String }) ?? [] {
            guard path.hasSuffix(".swift"), path != "SuiteUI/SuiteFilePanels.swift" else { continue }
            let text = try String(contentsOf: base.appendingPathComponent(path), encoding: .utf8)
            if text.contains("NSOpenPanel(") || text.contains("NSSavePanel(") { builders.insert("Sources/" + path) }
        }
        #expect(builders.subtracting(Self.unmoved).isEmpty, "use SuiteFilePanels: \(builders.subtracting(Self.unmoved).sorted())")
        #expect(Self.unmoved.subtracting(builders).isEmpty, "drop from unmoved: \(Self.unmoved.subtracting(builders).sorted())")
    }
}
