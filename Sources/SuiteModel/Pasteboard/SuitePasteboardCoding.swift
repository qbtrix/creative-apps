// SuitePasteboardCoding.swift (clipboard-interop CB-1 stub, CB-3 body): the live PasteboardCoding (UC-7) every app
// copies and pastes through. Pure and Linux-safe; SuiteShell's PasteboardBridge carries its `TypedData` to and
// from the system pasteboard, and the CLI's PasteboardFolder to and from a folder.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The suite's pasteboard coder. Until CB-3 it answers as `FakePasteboard`, with an app's own layer bytes added.
public struct SuitePasteboardCoding: PasteboardCoding {
    let fake = FakePasteboard()

    public init() {}

    /// Richest first: own layers, then SVG (vector items), then PNG, then TIFF (images), then text.
    public func representations(of item: SuiteClipItem) -> [TypedData] {
        fake.representations(of: item)
    }

    /// The best item `app` can take from what is offered, or nil.
    public func bestItem(from offered: [TypedData], for app: SuiteApp) -> SuiteClipItem? {
        fake.bestItem(from: offered, for: app)
    }

    /// nil when Paste can act in `app`; else why it is off, naming what the pasteboard holds.
    public func pasteRefusal(for offered: [TypedData], in app: SuiteApp) -> SuiteError? {
        fake.pasteRefusal(for: offered, in: app)
    }
}
