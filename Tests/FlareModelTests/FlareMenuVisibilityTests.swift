// FlareMenuVisibilityTests.swift (no-placeholders NP-3): the beta hides the menu items of onion skin, the motion path,
// Interactions, Assist and the symbol edits. Each stays a catalog command that, run headless, refuses with
// `laterReason`, and each id is in Flare's ledger.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import Testing
@testable import FlareModel

struct FlareMenuVisibilityTests {
    static let betaTwo: Set<String> = [
        "view.toggle-onion", "view.toggle-motion-path", "window.interactions", "window.assist",
        "library.convert-to-symbol", "library.exit-symbol",
    ]

    @Test func allBetaTwoHidden() {
        #expect(FlareWorkspace.menuHidden == Self.betaTwo)
        #expect(FlareWorkspace.laterReason("view.toggle-onion") == "Onion skin comes in a later beta.")
    }

    @Test func hiddenIsUnavailable() {
        var open = FlareWorkspace(services: .fake())
        open.newDocument()
        for ws in [FlareWorkspace(services: .fake()), open] {
            for id in Self.betaTwo.sorted() {
                let why = FlareWorkspace.laterReason(id)
                #expect(why.hasSuffix(" comes in a later beta.") && why.count > " comes in a later beta.".count, "\(id): \(why)")
                #expect(FlareWorkspace.catalog.availability(id, on: ws).why == why, "\(id) isn't unavailable with its reason")
                var run = ws
                #expect(throws: CatalogError.self, "\(id) ran") { try FlareWorkspace.catalog.run(id, params: .object([:]), on: &run) }
                #expect(run.document == ws.document, "\(id) changed the document")
            }
        }
    }

    @Test func hiddenIDsAreInTheLedger() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/flare.txt")
        let ledger = Set(try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init))
        #expect(Self.betaTwo.subtracting(ledger).sorted() == [], "a hidden id isn't in Tests/command-ids/flare.txt")
    }

    /// The menu items the window builds read `menuHidden` through their intent's command id.
    @Test func hiddenIntentsNameTheirCommand() {
        let intents: [FlareIntent] = [
            .view(.toggleOnion), .view(.toggleMotionPath), .interactions(.toggleEditor), .assist(.showPopover),
            .library(.convertToSymbol(name: "")), .library(.exitSymbol),
        ]
        #expect(Set(intents.compactMap(\.commandID)) == Self.betaTwo)
        #expect(FlareWorkspace.menuSpec(for: .view(.toggleOnion)).id == "view.toggle-onion")
        #expect(FlareIntent.view(.zoomIn).commandID.map(FlareWorkspace.menuHidden.contains) != true)
    }
}
