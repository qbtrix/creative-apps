// CommandIDLedgerTests.swift (command-catalog CC-6): a catalog's ids against its ledger (one id per line,
// "retired <id>" for a removed one): an id removed without retiring it fails, a retired id back fails, a new id
// passes. Written first, disabled by name; CC-8 builds `CommandIDLedger.check` and enables them.
import Testing
import SuiteKernel

@Suite struct CommandIDLedgerTests {
    static let ledger = "rect.add\nrect.move\nretired rect.old\n"

    @Test(.disabled("waits on CC-8")) func idsThatKeepTheLedgerPass() {
        #expect(CommandIDLedger.check(["rect.add", "rect.move"], ledger: Self.ledger).isEmpty)
        #expect(CommandIDLedger.check(["rect.move", "rect.add"], ledger: Self.ledger).isEmpty, "the order of ids is not part of the ledger")
    }

    @Test(.disabled("waits on CC-8")) func aNewIdPasses() {
        #expect(CommandIDLedger.check(["rect.add", "rect.move", "rect.remove"], ledger: Self.ledger).isEmpty)
        #expect(CommandIDLedger.check(["rect.add"], ledger: "").isEmpty)
    }

    @Test(.disabled("waits on CC-8")) func anIdRemovedWithoutRetiringFails() {
        let problems = CommandIDLedger.check(["rect.add"], ledger: Self.ledger)
        #expect(problems.count == 1 && problems.first?.contains("rect.move") == true)
        #expect(CommandIDLedger.check(["rect.add"], ledger: "rect.add\nretired rect.move\nretired rect.old\n").isEmpty)
    }

    @Test(.disabled("waits on CC-8")) func aRetiredIdNeverComesBack() {
        let problems = CommandIDLedger.check(["rect.add", "rect.move", "rect.old"], ledger: Self.ledger)
        #expect(problems.count == 1 && problems.first?.contains("rect.old") == true)
    }

    @Test(.disabled("waits on CC-8")) func everyProblemIsReported() {
        let problems = CommandIDLedger.check(["rect.old"], ledger: Self.ledger)
        #expect(problems.count == 3 && ["rect.add", "rect.move", "rect.old"].allSatisfy { id in problems.contains { $0.contains(id) } })
    }

    @Test(.disabled("waits on CC-8")) func theFakesIdsKeepALedgerOfThemselves() {
        let catalog = FakeCanvasDocument.catalog
        #expect(CommandIDLedger.check(catalog.ids, ledger: catalog.ids.joined(separator: "\n") + "\n").isEmpty)
    }
}
