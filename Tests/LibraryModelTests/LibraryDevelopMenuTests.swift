// LibraryDevelopMenuTests.swift: when the Develop menu's actions can run
// (LibraryDevelop+Menu.swift, develop DV-8). The rules are checked over plain
// inputs now; the catalog checks that need real targets wait on DV-3, which
// fills `developTargets` and `developHelp`. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

/// The shoot fixture's photo `IMG_<n>` (ids are paths).
private func shot(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

/// The shoot sorted by name on the fakes, in the grid.
private func shoot() -> LibraryCatalog {
    var catalog = LibraryCatalog(services: .fake())
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    catalog.setSort(.name)
    return catalog
}

private func rules(help: String? = nil, targets: Int, loupe: Bool) -> DevelopMenuRules {
    LibraryCatalog.developMenuRules(help: help, targetCount: targets, loupeShowsPhoto: loupe)
}

struct LibraryDevelopMenuTests {
    @Test func noTargetsEnablesNothing() {
        let catalog = shoot()
        #expect(!catalog.canEditDevelop && !catalog.canShowOriginal && !catalog.canCopySettings)
        let none = rules(targets: 0, loupe: true)
        #expect(!none.canEdit && !none.canShowOriginal && !none.canCopySettings)
    }

    @Test func twoSelectedInTheGridEditButNeitherCopyNorShowOriginal() {
        let grid = rules(targets: 2, loupe: false)
        #expect(grid.canEdit && !grid.canCopySettings && !grid.canShowOriginal)
    }

    @Test func aPhotoInTheLoupeEnablesAll() {
        let loupe = rules(targets: 1, loupe: true)
        #expect(loupe.canEdit && loupe.canShowOriginal && loupe.canCopySettings)
    }

    @Test func aHelpBlocksEditAndShowOriginalButNotCopy() {
        let blocked = rules(help: "Select a photo to develop it.", targets: 1, loupe: true)
        #expect(!blocked.canEdit && !blocked.canShowOriginal && blocked.canCopySettings)
    }

    @Test(.disabled("waits on DV-3")) func theCatalogReadsItsSelectionAndLoupe() {
        var catalog = shoot()
        catalog.select([shot(1), shot(2)])
        #expect(catalog.canEditDevelop && !catalog.canCopySettings && !catalog.canShowOriginal)
        catalog.open(shot(3))
        #expect(catalog.canEditDevelop && catalog.canShowOriginal && catalog.canCopySettings)
    }
}
