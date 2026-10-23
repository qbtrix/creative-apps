// FlareOpenQueue.swift: finding #4636. Animations waiting for a window: a
// .flare dropped on the stage, or reopened from File > Open Recent ▸ or
// Open In, reaches FlareShell.host, which asks this queue for a new window
// per file; the window takes the oldest waiting file when it appears
// (FlareOpenQueueTaker, applied in FlareWindow).
import SwiftUI

@MainActor final class FlareOpenQueue {
    static let shared = FlareOpenQueue()
    static let windowID = "flare"
    private var pending: [URL] = []
    /// The first window's `openWindow` (nil until a window appears).
    private var openWindow: OpenWindowAction?

    /// Opens `url` in a new window.
    func open(_ url: URL) {
        pending.append(url)
        openWindow?(id: Self.windowID)
    }

    /// A window appeared: the oldest file waiting for it, or nil. The first
    /// window also asks for one per file that came before it could.
    func windowAppeared(_ openWindow: OpenWindowAction) -> URL? {
        let first = self.openWindow == nil
        self.openWindow = openWindow
        let url = pending.isEmpty ? nil : pending.removeFirst()
        if first { for _ in pending { openWindow(id: Self.windowID) } }
        return url
    }
}

/// A window's side of the queue: once it appears, it opens the oldest waiting file.
struct FlareOpenQueueTaker: ViewModifier {
    let open: @MainActor (URL) -> Void
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.task { if let url = FlareOpenQueue.shared.windowAppeared(openWindow) { open(url) } }
    }
}
