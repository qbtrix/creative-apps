// LibraryShellClaimTests.swift: LibraryShell's live channel belongs to the
// window that claimed it last. An earlier window's onDisappear, landing after
// a newer window's onAppear, leaves the newer claim in place (#6123: the
// heavy run's export budget read a nil channel). Nested in BodyCountSuites so
// it never runs beside a window that holds the channel. macOS only.
#if canImport(AppKit)
import Foundation
import LibraryModel
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct LibraryShellClaimTests {
        @Test func anOlderWindowsReleaseKeepsTheNewerClaim() {
            let (old, new) = (UUID(), UUID())
            let catalog = LibraryCatalog(services: .fake())
            LibraryShell.claim(old, read: { catalog }, take: { _ in })
            LibraryShell.claim(new, read: { catalog }, take: { _ in })
            LibraryShell.release(old)
            #expect(LibraryShell.read != nil, "the old window's close cleared the new window's channel")
            #expect(LibraryShell.take != nil)
            LibraryShell.release(new)
            #expect(LibraryShell.read == nil, "the owner's close left the channel set")
            #expect(LibraryShell.take == nil)
        }
    }
}
#endif
