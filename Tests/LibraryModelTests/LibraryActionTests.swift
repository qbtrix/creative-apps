// LibraryActionTests.swift: LibraryCatalog's actions (LibraryActions.swift).
// Each moved menu or key action does what its closure in LibraryApp did on
// the sample catalog, and, where the closure was nil (its item disabled),
// refuses with the menu's reason and changes nothing. Runs on Linux and macOS.
import LibraryModel
import Testing

@Suite struct LibraryActionTests {
    /// The 60 sample photos in the grid; `selected` of them selected in sort order.
    private func samples(selected: Int = 0, mode: FakeMode = .ok) -> LibraryCatalog {
        var catalog = LibraryCatalog(services: .fake(mode: mode))
        catalog.loadSamples()
        catalog.select(Set(catalog.order.prefix(selected)))
        return catalog
    }

    /// `action` run on `catalog` leaves it as `closure` did, with no refusal.
    private func expectSame(
        _ action: LibraryAction, on catalog: LibraryCatalog, as closure: (inout LibraryCatalog) -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var expected = catalog
        closure(&expected)
        var actual = catalog
        #expect(actual.help(action) == nil, sourceLocation: sourceLocation)
        #expect(throws: Never.self, sourceLocation: sourceLocation) { try actual.run(action) }
        #expect(actual == expected, "\(action)", sourceLocation: sourceLocation)
    }

    /// `action` refuses on `catalog` with `reason` and leaves it unchanged.
    private func expectRefused(
        _ action: LibraryAction, on catalog: LibraryCatalog, _ reason: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var actual = catalog
        #expect(actual.help(action) == reason, "\(action)", sourceLocation: sourceLocation)
        #expect(throws: LibraryRefusal(reason), sourceLocation: sourceLocation) { try actual.run(action) }
        #expect(actual == catalog, "\(action)", sourceLocation: sourceLocation)
    }

    @Test func gridActionsDoWhatTheirClosuresDid() {
        var rated = samples(selected: 2)
        rated.setRating(4)
        let grid = samples(selected: 3)
        expectSame(.undo, on: rated) { $0.undo() }
        var undone = rated
        undone.undo()
        expectSame(.redo, on: undone) { $0.redo() }
        expectSame(.selectAll, on: grid) { $0.select(Set($0.order)) }
        expectSame(.deselect, on: grid) { $0.select([]) }
        expectSame(.loadSamples, on: grid) { $0.loadSamples() }
        expectSame(.setRating(3), on: grid) { $0.setRating(3) }
        expectSame(.setFlag(.pick), on: grid) { $0.setFlag(.pick) }
        expectSame(.setLabel(.blue), on: grid) { $0.setLabel(.blue) }
        expectSame(.cull(.rating(2)), on: grid) { $0.cull(.rating(2)) }
        expectSame(.toggleAutoAdvance, on: grid) { $0.setAutoAdvance(!$0.autoAdvance) }
        expectSame(.dismissCullError, on: grid) { $0.dismissCullError() }
        expectSame(.showLoupe, on: grid) { $0.showLoupe() }
        expectSame(.setSort(.rating), on: grid) { $0.setSort(.rating) }
        expectSame(.zoomIn(fitScale: 0.3), on: grid) { $0.stepCellSize(by: 1) }
        expectSame(.zoomOut(fitScale: 0.3), on: grid) { $0.stepCellSize(by: -1) }
    }

    @Test func loupeActionsDoWhatTheirClosuresDid() throws {
        var loupe = samples(selected: 1)
        loupe.open(try #require(loupe.order.dropFirst(5).first))
        expectSame(.showGrid, on: loupe) { $0.showGrid() }
        expectSame(.showFirst, on: loupe) { $0.showFirstInLoupe() }
        expectSame(.showLast, on: loupe) { $0.showLastInLoupe() }
        expectSame(.zoomIn(fitScale: 0.3), on: loupe) { $0.stepZoom(by: 1, fitScale: 0.3) }
        expectSame(.zoomOut(fitScale: 0.3), on: loupe) { $0.stepZoom(by: -1, fitScale: 0.3) }
        expectSame(.actualSize, on: loupe) { $0.zoomLoupe(.actual) }
        expectSame(.zoomTo(2, fitScale: 0.3), on: loupe) { $0.zoomLoupe(.scale(2)) }
        expectSame(.zoomTo(0.30001, fitScale: 0.3), on: loupe) { $0.zoomLoupe(.fit) }
        expectSame(.cull(.flag(.reject)), on: loupe) { $0.cull(.flag(.reject)) }
        var zoomed = loupe
        zoomed.zoomLoupe(.actual)
        expectSame(.zoomToFit, on: zoomed) { $0.zoomLoupe(.fit) }
    }

    @Test func refusalsCarryTheMenuReason() throws {
        let empty = LibraryCatalog(services: .fake())
        expectRefused(.undo, on: empty, "There is nothing to undo.")
        expectRefused(.redo, on: empty, "There is nothing to redo.")
        expectRefused(.selectAll, on: empty, "There are no photos to select.")
        expectRefused(.setSort(.name), on: empty, "There are no photos to sort.")
        expectRefused(.showLoupe, on: empty, "The loupe is already showing, or there are no photos.")
        let grid = samples()
        expectRefused(.deselect, on: grid, "No photos are selected.")
        expectRefused(.setFlag(.pick), on: grid, "Select photos first.")
        expectRefused(.cull(.rating(1)), on: grid, "Select photos first.")
        expectRefused(.showGrid, on: grid, "The grid is already showing.")
        expectRefused(.zoomToFit, on: grid, "Open a photo in the loupe to zoom.")
        expectRefused(.actualSize, on: grid, "Open a photo in the loupe to zoom.")
        expectRefused(.dismissImportNotice, on: grid, "There is no import notice to close.")
        var largest = grid
        largest.stepCellSize(by: 10)
        expectRefused(.zoomIn(fitScale: 1), on: largest, "Can't zoom in further.")
        var loupe = grid
        loupe.open(try #require(loupe.order.first))
        expectRefused(.zoomToFit, on: loupe, "The photo already fits.")
        expectRefused(.showFirst, on: loupe, "The loupe is already on the first photo.")
        var deepest = loupe
        deepest.zoomLoupe(.scale(8))
        expectRefused(.zoomIn(fitScale: 0.3), on: deepest, "Can't zoom in further.")
    }

    @Test func aServicesReasonComesFirst() {
        var services = LibraryServices.fake()
        services.unavailable = ["culling": "Rating isn't connected yet."]
        var catalog = LibraryCatalog(services: services)
        catalog.loadSamples()
        expectRefused(.setLabel(.red), on: catalog, "Rating isn't connected yet.")
    }

    @Test func ratingRange() throws {
        let grid = samples(selected: 2)
        expectSame(.setRating(5), on: grid) { $0.setRating(5) }
        expectSame(.setRating(0), on: grid) { $0.setRating(0) }
        expectRefused(.setRating(6), on: grid, LibraryCatalog.ratingRangeReason)
        expectRefused(.setRating(-1), on: grid, LibraryCatalog.ratingRangeReason)
    }

    @Test func sampleRefusalHint() throws {
        var catalog = samples(selected: 2, mode: .fail)
        let refusal = try #require(throws: LibraryRefusal.self) { try catalog.run(.setFlag(.pick)) }
        #expect(refusal.reason.hasSuffix(LibraryNoticeContent.importHint))
        #expect(refusal.reason == catalog.cullError)
        #expect(catalog.notice?.action == .importFolder)
        #expect(catalog.history.undo.isEmpty)
    }
}
