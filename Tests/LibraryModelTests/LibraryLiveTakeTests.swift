// LibraryLiveTakeTests.swift (editor-menus EM-7): the live command channel reads the window's catalog as a
// headless document, runs a command on it, and the window takes the result back. LibraryApp adopts the suite
// editor's menus and reopens its window from the Dock; the source check reads LibraryApp.swift, which builds only
// on macOS. Linux-safe.
import Foundation
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryLiveTakeTests {
    @Test func theWindowBecomesTheCatalogTheCommandRanOn() throws {
        let doc = try LibraryHeadless.open(LibraryHeadlessTests.input("cull-and-save"), name: "shoot.library")
        var window = doc.library
        var ran = LibraryHeadless(catalog: window)
        #expect(ran.library == window)
        _ = try LibraryHeadless.catalog.run("edit.select", params: .object(["ids": .array([.string("fog")])]), on: &ran)
        _ = try LibraryHeadless.catalog.run("metadata.set-rating", params: .object(["stars": .number(3)]), on: &ran)
        #expect(window != ran.library)
        window.takeLive(ran)
        #expect(window == ran.library)
        #expect(window.items.first { $0.id == "fog" }?.rating == 3)
    }

    @Test func libraryAppAdoptsTheSuiteEditor() throws {
        let app = try source("Sources/LibraryApp/LibraryApp.swift")
        #expect(app.contains(".suiteEditor(.library, host: LibraryShell.host, live: LibraryShell.live)"))
        #expect(app.contains(".suiteReopenWindow(id: \"library\")"))
        #expect(app.contains("@NSApplicationDelegateAdaptor"))
        #expect(!app.contains(".suiteApp("))
    }
}

private func packageRoot() -> URL? {
    var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while dir.path != "/" {
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
        dir = dir.deletingLastPathComponent()
    }
    return nil
}

/// The file at `path` under the package root, less its comment lines.
private func source(_ path: String) throws -> String {
    let root = try #require(packageRoot())
    let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    return text.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n")
}
