// DesignPasteboardBridgeTests.swift: DesignPasteboardBridge moves layer bytes
// under Design's own pasteboard type unchanged, reads nothing for another type,
// and never clears the pasteboard when it reads (design-window D0-5d). Each
// test uses its own private named pasteboard, released after, so the general
// pasteboard is never touched. macOS only.
import AppKit
import DesignModel
import Foundation
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignPasteboardBridgeTests {
    private let type = "org.creativesuite.design.layers"
    private let bytes = Data([0x7B, 0x22, 0x6C, 0x22, 0x3A, 0x5B, 0x5D, 0x7D, 0x00, 0xFF])

    private func withBridge(_ body: (DesignPasteboardBridge, NSPasteboard) -> Void) {
        let pasteboard = NSPasteboard(name: .init("design-window-test-\(UUID().uuidString)"))
        body(DesignPasteboardBridge(pasteboard: pasteboard), pasteboard)
        pasteboard.releaseGlobally()
    }

    @Test func theModelsTypeIsTheOneTheBridgeUses() {
        #expect(DesignWorkspace().pasteboardType == type)
    }

    @Test func bytesWrittenReadBackEqual() {
        withBridge { bridge, _ in
            bridge.write(bytes, type: type)
            #expect(bridge.read(type: type) == bytes)
        }
    }

    @Test func plainTextReadsAsNilForOurType() {
        withBridge { bridge, pasteboard in
            pasteboard.clearContents()
            _ = pasteboard.setString("Avatar", forType: .string)
            #expect(bridge.read(type: type) == nil)
        }
    }

    @Test func readingNeverClearsIt() {
        withBridge { bridge, pasteboard in
            bridge.write(bytes, type: type)
            let count = pasteboard.changeCount
            #expect(bridge.read(type: type) == bytes)
            #expect(bridge.read(type: type) == bytes)
            #expect(pasteboard.changeCount == count)
            #expect(pasteboard.types?.contains(.init(type)) == true)
        }
    }

    @Test func aWriteReplacesWhatWasThere() {
        withBridge { bridge, pasteboard in
            pasteboard.clearContents()
            _ = pasteboard.setString("Avatar", forType: .string)
            bridge.write(bytes, type: type)
            #expect(pasteboard.string(forType: .string) == nil)
            #expect(bridge.read(type: type) == bytes)
        }
    }
}
