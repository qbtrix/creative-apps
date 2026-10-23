// AutosaveQuitTests.swift (#4015): the two decisions `.autosaveRecovery` leaves to the kernel. On quit, a dirty
// window writes its newest edit at once, without waiting for the delay, and a clean or already-written one writes
// nothing. A Restore that throws keeps the copy on disk and says why; one that works lets the next save delete it.
import Foundation
import SuiteKernel
import Testing

@Suite struct AutosaveQuitTests {
    @Test func dirtyQuitWritesInsideTheDelay() {
        var schedule = AutosaveSchedule(delay: 2)
        schedule.noteEdit(at: 10)
        #expect(schedule.begin(now: 10.5, dirty: true) == nil)
        #expect(schedule.beginQuit(now: 10.5, dirty: true)?.edit == 10)
    }
    @Test func cleanQuitWritesNothing() {
        var schedule = AutosaveSchedule(delay: 2)
        schedule.noteEdit(at: 10)
        #expect(schedule.beginQuit(now: 10.5, dirty: false) == nil)
        var fresh = AutosaveSchedule(delay: 2)
        #expect(fresh.beginQuit(now: 1, dirty: false) == nil)
    }
    @Test func quitAfterALandedWriteWritesNothing() throws {
        var schedule = AutosaveSchedule(delay: 2)
        schedule.noteEdit(at: 10)
        let begun = schedule.begin(now: 12, dirty: true)
        let ticket = try #require(begun)
        #expect(schedule.finish(ticket, wrote: true) == .keep)
        #expect(schedule.beginQuit(now: 13, dirty: true) == nil)
    }
    @Test func quitWritesTheEditAfterALandedWrite() throws {
        var schedule = AutosaveSchedule(delay: 2)
        schedule.noteEdit(at: 10)
        let begun = schedule.begin(now: 12, dirty: true)
        let ticket = try #require(begun)
        _ = schedule.finish(ticket, wrote: true)
        schedule.noteEdit(at: 13)
        let quitting = schedule.beginQuit(now: 13.5, dirty: true)
        let quit = try #require(quitting)
        #expect(quit.edit == 13)
        #expect(schedule.finish(quit, wrote: true) == .keep)
        #expect(schedule.isWritten)
    }
    @Test func dirtyQuitWithNoNotedEditStillWrites() {
        var schedule = AutosaveSchedule(delay: 2)
        #expect(schedule.beginQuit(now: 7, dirty: true)?.edit == 7)
    }
    @Test func quitWritesEvenWhenTheDelayIsNeverDue() {
        var schedule = AutosaveSchedule(delay: .nan)
        schedule.noteEdit(at: 10)
        #expect(schedule.beginQuit(now: 10, dirty: true)?.edit == 10)
    }

    @Test func aRestoreThatWorksLetsTheNextSaveDeleteTheCopy() {
        let outcome = RecoveryRestore(name: "Poster", failure: nil)
        #expect(outcome == .restored)
        #expect(outcome.deletesCopyOnSave)
        #expect(outcome.message == nil)
    }
    @Test func aRestoreThatThrowsKeepsTheCopyAndSaysWhy() throws {
        let outcome = RecoveryRestore(name: "Poster", failure: "The data is damaged.")
        #expect(!outcome.deletesCopyOnSave)
        let message = try #require(outcome.message)
        #expect(message.contains("\u{201C}Poster\u{201D}"))
        #expect(message.contains("The data is damaged."))
        #expect(message.contains("kept"))
    }
    @Test func anEmptyReasonStillFails() {
        let outcome = RecoveryRestore(name: "Untitled", failure: "")
        #expect(!outcome.deletesCopyOnSave)
        #expect(outcome.message?.contains("\u{201C}Untitled\u{201D}") == true)
    }
}
