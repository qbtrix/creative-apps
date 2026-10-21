// BetaNotesTests.swift (report-problem RP-1, written first; RP-4 turns them on): Help > Beta Notes lists the
// build's known issues, each with a title and a detail, no two titles alike. Linux-safe.
import SuiteModel
import Testing

@Suite struct BetaNotesTests {
    @Test(.disabled("waits on RP-4")) func listsTheKnownIssues() {
        #expect(!BetaNotes.current.isEmpty)
    }

    @Test(.disabled("waits on RP-4")) func everyNoteHasATitleAndADetail() {
        for note in BetaNotes.current {
            #expect(!note.title.isEmpty && !note.detail.isEmpty, "\(note.title)")
            #expect(note.title.count <= 80, "a title fits one line: \(note.title)")
        }
    }

    @Test(.disabled("waits on RP-4")) func noTwoTitlesAlike() {
        let titles = BetaNotes.current.map(\.title)
        #expect(Set(titles).count == titles.count)
    }
}
