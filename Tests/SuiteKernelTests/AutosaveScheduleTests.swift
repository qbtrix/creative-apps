// AutosaveScheduleTests.swift (autosave-history AH-1 written, AH-5 turns on): when an open document writes its
// recovery copy. No ticket before the delay, one ticket per edit, a write a save or discard overtook is deleted,
// a failed write waits for the next edit, and a delay that isn't a finite non-negative number is never due.
// AH-5 built `AutosaveSchedule`'s body and turned every test on.
import Testing
import SuiteKernel

@Suite struct AutosaveScheduleTests {
    /// A two-second schedule with one edit at 10.
    static func edited() -> AutosaveSchedule {
        var schedule = AutosaveSchedule(delay: 2)
        schedule.noteEdit(at: 10)
        return schedule
    }

    @Test func noTicketBeforeDelay() {
        var schedule = AutosaveSchedule(delay: 2)
        #expect(schedule.begin(now: 100, dirty: true) == nil)
        schedule.noteEdit(at: 10)
        #expect(schedule.begin(now: 11, dirty: true) == nil)
        #expect(schedule.begin(now: 11.999, dirty: true) == nil)
        #expect(!schedule.isWritten)
    }
    @Test func dueExactlyAtDelay() {
        var schedule = Self.edited()
        #expect(schedule.begin(now: 12, dirty: true)?.edit == 10)
    }
    @Test func cleanDocumentNeverDue() {
        var schedule = Self.edited()
        #expect(schedule.begin(now: 100, dirty: false) == nil)
    }
    @Test func oneTicketPerEdit() throws {
        var schedule = Self.edited()
        let begun = schedule.begin(now: 12, dirty: true)
        let ticket = try #require(begun)
        #expect(schedule.begin(now: 13, dirty: true) == nil)
        #expect(schedule.finish(ticket, wrote: true) == .keep)
        #expect(schedule.isWritten)
        #expect(schedule.begin(now: 20, dirty: true) == nil)
        schedule.noteEdit(at: 21)
        #expect(!schedule.isWritten)
        #expect(schedule.begin(now: 22, dirty: true) == nil)
        #expect(schedule.begin(now: 23, dirty: true)?.edit == 21)
    }
    @Test func saveDuringWriteDiscards() throws {
        var schedule = Self.edited()
        let begun = schedule.begin(now: 12, dirty: true)
        let ticket = try #require(begun)
        schedule.didSave(stillDirty: false)
        #expect(schedule.finish(ticket, wrote: true) == .discard)
        #expect(!schedule.isWritten)
        #expect(schedule.begin(now: 100, dirty: true) == nil)
    }
    @Test func discardDuringWriteDiscards() throws {
        var schedule = Self.edited()
        let begun = schedule.begin(now: 12, dirty: true)
        let ticket = try #require(begun)
        schedule.didDiscard()
        #expect(schedule.finish(ticket, wrote: true) == .discard)
        #expect(schedule.begin(now: 100, dirty: true) == nil)
    }
    @Test func editDuringSaveStaysDue() {
        var schedule = Self.edited()
        schedule.didSave(stillDirty: true)
        #expect(schedule.begin(now: 12, dirty: true)?.edit == 10)
    }
    @Test func failedWriteWaitsForEdit() throws {
        var schedule = Self.edited()
        let begun = schedule.begin(now: 12, dirty: true)
        let ticket = try #require(begun)
        #expect(schedule.finish(ticket, wrote: false) == .retryOnNextEdit)
        #expect(!schedule.isWritten)
        #expect(schedule.begin(now: 13, dirty: true) == nil)
        #expect(schedule.begin(now: 50, dirty: true) == nil)
        schedule.noteEdit(at: 51)
        #expect(schedule.begin(now: 53, dirty: true)?.edit == 51)
    }
    @Test func nanDelayNeverDue() {
        for delay in [Double.nan, -1, .infinity, -.infinity] {
            var schedule = AutosaveSchedule(delay: delay)
            schedule.noteEdit(at: 10)
            #expect(schedule.begin(now: 1e9, dirty: true) == nil, "\(delay)")
        }
    }
}
