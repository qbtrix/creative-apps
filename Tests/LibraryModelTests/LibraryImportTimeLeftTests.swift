// LibraryImportTimeLeftTests.swift: the import progress row's time left
// (#3640). The rest is estimated at the pace so far (elapsed / done × left),
// said in whole minutes rounded up, "less than a minute" under 60 s, and not
// at all before a file is done, before a second has passed, or once all are.
import LibraryModel
import Testing

@Suite struct LibraryImportTimeLeftTests {
    @Test func theRestTakesThePaceSoFar() {
        #expect(ImportProgress(done: 10, total: 40, elapsed: 30).secondsLeft == 90)
        #expect(ImportProgress(done: 10, total: 40, elapsed: 30).text == "Importing 11 of 40, about 2 minutes left")
        #expect(ImportProgress(done: 20, total: 40, elapsed: 60).text == "Importing 21 of 40, about 1 minute left")
        #expect(ImportProgress(done: 10, total: 17, elapsed: 100).text == "Importing 11 of 17, about 2 minutes left")
        #expect(ImportProgress(done: 30, total: 40, elapsed: 30).text == "Importing 31 of 40, less than a minute left")
    }

    @Test func noEstimateWithoutAPace() {
        #expect(ImportProgress(done: 2, total: 27).text == "Importing 3 of 27")
        #expect(ImportProgress(done: 0, total: 24, elapsed: 5).secondsLeft == nil)
        #expect(ImportProgress(done: 3, total: 24, elapsed: 0.5).secondsLeft == nil)
        #expect(ImportProgress(done: 24, total: 24, elapsed: 9).secondsLeft == nil)
        #expect(ImportProgress(done: 3, total: 24, elapsed: 1).secondsLeft == 7)
    }
}
