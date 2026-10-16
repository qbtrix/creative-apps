// LibraryImportSnapshots.swift: the import feature's five content states
// (import IM-7) in Light and Dark, each built through the catalog's public
// import methods: an import running with its progress row ("Importing 3 of
// 27") over its first batch of grey cells, the notice after a clean import,
// after one with failures (listed), after one that found nothing new, and the
// error notice for an unreadable folder, all with the window's import actions
// enabled. Writes library-importing, library-imported,
// library-import-failures, library-import-nothing-new and
// library-import-denied, each -{light,dark}.png. macOS only.
import AppKit
import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryImportSnapshots {
    /// The sample photos, as an importer's batches would bring them in.
    private var samplePhotos: [PhotoItem] {
        var samples = LibraryCatalog()
        samples.loadSamples()
        return samples.items
    }

    /// An import's first batch, built as LiveImporter builds it: id == path,
    /// neutral grey, no rating, flag or label.
    private var firstBatch: [PhotoItem] {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        return (1...3).map { n in
            let path = "/Shoot/jpeg-000\(n).jpg"
            return PhotoItem(
                id: path, name: "jpeg-000\(n)", captureDate: start.addingTimeInterval(Double(n) * 60),
                color: Color3(0.5, 0.5, 0.5), path: path)
        }
    }

    @Test func importStates() throws {
        let photos = samplePhotos
        #expect(photos.count >= 4)

        var importing = LibraryCatalog()
        #expect(importing.beginImport() != nil)
        importing.showImportProgress(ImportProgress(done: 2, total: 27))
        importing.appendImported(firstBatch)
        #expect(importing.importState == .running(ImportProgress(done: 2, total: 27)))
        #expect(importing.items.count == 3)
        #expect(importing.items.allSatisfy { $0.rating == 0 && $0.label == nil && $0.flag == PhotoFlag.none &&$0.id == $0.path })

        var imported = LibraryCatalog()
        _ = imported.beginImport()
        imported.appendImported(Array(photos.prefix(2)))
        imported.finishImport(ImportResult(added: photos, alreadyKnown: 0, failures: []), folder: "Shoot")
        #expect(imported.importNotice?.isError == false && imported.importNotice?.failures.isEmpty == true)

        var failures = LibraryCatalog()
        _ = failures.beginImport()
        let failed = [
            FileFailure(path: "/Shoot/broken.jpg", reason: "not an image file"),
            FileFailure(path: "/Shoot/day2/cut.heic", reason: "not an image file"),
        ]
        failures.finishImport(ImportResult(added: photos, alreadyKnown: 0, failures: failed), folder: "Shoot")
        #expect(failures.importNotice?.message.hasSuffix(" 2 files couldn't be imported.") == true)
        #expect(failures.importNotice?.isError == false)

        var nothingNew = imported
        _ = nothingNew.beginImport()
        nothingNew.finishImport(ImportResult(added: [], alreadyKnown: photos.count, failures: []), folder: "Shoot")
        #expect(nothingNew.importNotice?.message == "No new photos in Shoot.")

        var denied = LibraryCatalog()
        _ = denied.beginImport()
        denied.failImport(.unreadableFolder("Shoot"), folder: "Shoot")
        #expect(denied.importNotice?.isError == true)
        #expect(denied.importNotice?.message == "Library can't read Shoot. Check that you have access to it.")

        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(browser(importing), name: "library-importing-\(suffix)", scheme: scheme)
            try snapshot(browser(imported), name: "library-imported-\(suffix)", scheme: scheme)
            try snapshot(browser(failures, expanded: true), name: "library-import-failures-\(suffix)", scheme: scheme)
            try snapshot(browser(nothingNew), name: "library-import-nothing-new-\(suffix)", scheme: scheme)
            try snapshot(browser(denied), name: "library-import-denied-\(suffix)", scheme: scheme)
        }
    }

    /// The progress row is `library.import.progress`, its label and value the
    /// progress text (journeys read the label).
    @Test func progressRowIsIdentifiedWithItsText() {
        let row = LibraryImportProgressRow(progress: ImportProgress(done: 2, total: 27))
        #expect(LibraryImportProgressRow.identifier == "library.import.progress")
        #expect(row.value == "Importing 3 of 27")
        #expect(row.label == "Importing 3 of 27")
        #expect(row.fraction.value == 2 && row.fraction.total == 27)
        let empty = LibraryImportProgressRow(progress: ImportProgress(done: 0, total: 0))
        #expect(empty.fraction.value == 0 && empty.fraction.total == 1)
    }

    /// With a delay above zero the row starts hidden and shows once the delay
    /// passes (#1379: the delay's task hung on an empty Group never ran).
    @Test func progressRowShowsAfterItsDelay() {
        let row = LibraryImportProgressRow(progress: ImportProgress(done: 0, total: 24), delay: .milliseconds(10))
        let host = NSHostingView(rootView: row.frame(width: 600))
        host.frame = CGRect(x: 0, y: 0, width: 600, height: 200)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.height < 1, "the row showed before its delay")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.height > 0, "the row never showed after its 10 ms delay")
    }

    /// A clean import's notice is success green with the checkmark; a
    /// nothing-new notice is secondary text with the info symbol (#1378).
    @Test func noticeUsesItsStateColor() {
        let clean = LibraryImportNoticeRow(notice: ImportNotice(folder: "Shoot", added: 26), onClose: nil)
        #expect(clean.symbol == "checkmark.circle")
        #expect(clean.tint == SuiteColor.stateSuccess)
        let nothingNew = LibraryImportNoticeRow(notice: ImportNotice(folder: "Shoot", alreadyKnown: 26), onClose: nil)
        #expect(nothingNew.symbol == "info.circle")
        #expect(nothingNew.tint == SuiteColor.textSecondary)
    }

    /// With the window's import actions, the denied empty state offers an
    /// enabled Import Folder… and no "isn't connected" hint (#1380).
    @Test func deniedOffersAnEnabledImport() {
        var denied = LibraryCatalog()
        _ = denied.beginImport()
        denied.failImport(.unreadableFolder("Shoot"), folder: "Shoot")
        let browser = LibraryBrowser(model: denied, menu: Self.importMenu)
        #expect(browser.importAction.unavailableHelp == nil)
        #expect(!denied.emptyState(importReason: browser.importAction.unavailableHelp).message.contains("isn't connected"))
    }

    /// The notice lists each failure as `name: reason`.
    @Test func noticeListsFailuresByName() {
        let notice = ImportNotice(
            folder: "Shoot", added: 26, failures: [FileFailure(path: "/tmp/Shoot/broken.jpg", reason: "not an image file")])
        let row = LibraryImportNoticeRow(notice: notice, onClose: nil)
        #expect(row.failureLines == ["broken.jpg: not an image file"])
        #expect(LibraryImportNoticeRow.identifier == "library.import.notice")
    }

    /// The window's File actions: Import Folder… and the notice's close enabled.
    private static let importMenu = LibraryMenu(file: LibraryMenu.File(importFolder: {}, dismissImportNotice: {}))

    /// The browser with the window's import actions, the progress row at once
    /// (no 100 ms wait) and the rows pinned to the top, as in the window.
    private func browser(_ model: LibraryCatalog, expanded: Bool = false) -> some View {
        LibraryBrowser(
            model: model, menu: Self.importMenu, importProgressDelay: .zero, importFailuresExpanded: expanded)
            .frame(width: 1440, height: 900, alignment: .top)
    }
}
