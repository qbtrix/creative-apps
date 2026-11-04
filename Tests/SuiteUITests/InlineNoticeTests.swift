// InlineNoticeTests.swift: SuiteUI's InlineNotice, the one notice row every
// app shows at the top of a content area: each kind has its own symbol and
// state color (an error is never drawn as a warning), a caller's symbol wins,
// the close is drawn only when passed, and detail lines make the row taller
// rather than clip. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct InlineNoticeTests {
    @Test func eachKindHasItsSymbolAndColor() {
        #expect(NoticeKind.info.symbol == "info.circle" && NoticeKind.info.color == SuiteColor.textSecondary)
        #expect(NoticeKind.success.symbol == "checkmark.circle" && NoticeKind.success.color == SuiteColor.stateSuccess)
        #expect(NoticeKind.warning.symbol == "exclamationmark.triangle" && NoticeKind.warning.color == SuiteColor.stateWarning)
        #expect(NoticeKind.error.symbol == "exclamationmark.octagon" && NoticeKind.error.color == SuiteColor.stateError)
    }

    @Test func aCallersSymbolWinsAndTheCloseIsOptional() {
        let plain = InlineNotice("Imported 26 photos.", kind: .success, identifier: "n")
        #expect(plain.systemImage == "checkmark.circle" && plain.close == nil)
        let removed = InlineNotice("Cards.design removed from Recents.", kind: .info, systemImage: "trash", identifier: "n",
                                   close: ToolbarAction("Close", systemImage: "xmark", identifier: "n.close"))
        #expect(removed.systemImage == "trash" && removed.close?.identifier == "n.close")
    }

    @Test func detailLinesMakeTheRowTaller() {
        let one = NSHostingView(rootView: InlineNotice("1 file couldn't be imported.", kind: .warning, identifier: "n").frame(width: 600))
        let listed = NSHostingView(rootView: InlineNotice(
            "1 file couldn't be imported.", kind: .warning, identifier: "n", detail: ["a.jpg: not an image file", "b.jpg: unreadable"]
        ).frame(width: 600))
        #expect(one.fittingSize.height > 0)
        #expect(listed.fittingSize.height > one.fittingSize.height, "the detail lines should stack under the message")
    }
}
