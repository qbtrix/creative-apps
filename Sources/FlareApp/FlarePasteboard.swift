// FlarePasteboard.swift: Flare's Cut, Copy and Paste on the system pasteboard (stage-edit SE-3, rule 20).
// The bytes are the Model's `copy()` output, written under the suite's shared `SuiteTypeID.flareLayers`
// ("org.creativesuite.flare.layers"); no private type. SuiteShell's PasteboardSlot can't carry them: it wraps
// SuiteModel's FakePasteboard, a pure coder with no system transport that skips the app layer types, so this
// writes `NSPasteboard.general` directly, the way DesignPasteboardBridge does for `designLayers`.
// Another app can change the pasteboard and says nothing, so FlarePasteboardWatch polls its change count
// four times a second (Photo's shape) and publishes it, and the Edit menu re-reads Paste's reason.
import AppKit
import SuiteModel
import SwiftUI

@MainActor enum FlarePasteboard {
    /// The suite's Flare layers type on the system pasteboard.
    static let type = NSPasteboard.PasteboardType(SuiteTypeID.flareLayers.rawValue)

    /// Puts `data` on the pasteboard as Flare layers; nil (nothing copied) leaves it as it was.
    static func write(_ data: Data?) {
        guard let data else { return }
        let board = NSPasteboard.general
        _ = board.declareTypes([type], owner: nil)
        _ = board.setData(data, forType: type)
    }

    /// The Flare layers on the pasteboard; nil when it holds none.
    static func read() -> Data? { NSPasteboard.general.data(forType: type) }
}

/// Publishes the pasteboard's change count to the menu bar while the stage shows.
struct FlarePasteboardWatch: ViewModifier {
    @State private var change = 0

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.flarePasteboardChange, change)
            .task {
                while !Task.isCancelled {
                    let count = NSPasteboard.general.changeCount
                    if count != change { change = count }
                    do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                }
            }
    }
}

extension FocusedValues {
    /// The system pasteboard's change count as the focused Flare window last saw it.
    var flarePasteboardChange: Int? {
        get { self[FlarePasteboardChangeKey.self] }
        set { self[FlarePasteboardChangeKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, as FlareMenuKey.
private struct FlarePasteboardChangeKey: FocusedValueKey {
    typealias Value = Int
}
