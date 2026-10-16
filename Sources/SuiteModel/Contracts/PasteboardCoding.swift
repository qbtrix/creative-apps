// PasteboardCoding.swift: a suite contract from blueprint suite.md 5.2. Every throwing
// requirement throws `SuiteError`, whose `message` is the sentence the UI shows.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-7 Typed pasteboard and drag data between apps (tier 1). Pure; SuiteShell
/// maps `TypedData` to and from NSPasteboard items and drag providers.
public protocol PasteboardCoding: Sendable {
    /// Richest first: the suite envelope, then SVG or PNG, then text.
    func representations(of item: SuiteClipItem) -> [TypedData]
    /// The best item this app can take from what is offered, or nil.
    func bestItem(from offered: [TypedData], for app: SuiteApp) -> SuiteClipItem?
    /// nil when Paste can act in this app; else why it is disabled.
    func pasteRefusal(for offered: [TypedData], in app: SuiteApp) -> SuiteError?
}
