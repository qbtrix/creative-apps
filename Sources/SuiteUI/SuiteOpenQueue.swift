// SuiteOpenQueue.swift: files waiting for one of an app's windows (a dropped
// file, File > Open Recent ▸, Open In from another app). An empty window
// takes the file in place, as a document app's untitled window does; else a
// new window of the app's `WindowGroup(id:)` is asked for and takes the
// oldest waiting file when it appears. The first window to appear also asks
// for one per file that came before any window could. A window that takes a
// file stops counting as empty at once, so a second file never lands on top
// of the first. Windows join through `suiteOpenQueue(_:isEmpty:open:)`.
import SwiftUI

@MainActor public final class SuiteOpenQueue {
    public let windowID: String
    private var pending: [URL] = []
    /// Asks for a new window (the first window's `openWindow`); nil until a window appears.
    private var requestWindow: (@MainActor () -> Void)?
    /// The empty windows, oldest first, each with its own open.
    private var empty: [(id: UUID, open: @MainActor (URL) -> Void)] = []

    public init(windowID: String) { self.windowID = windowID }

    /// Opens `url` in an empty window, else in a new one.
    public func open(_ url: URL) {
        if !empty.isEmpty {
            empty.removeFirst().open(url)
            return
        }
        pending.append(url)
        requestWindow?()
    }

    /// A window appeared: the oldest file waiting for it, or nil.
    public func windowAppeared(requestWindow: @escaping @MainActor () -> Void) -> URL? {
        let first = self.requestWindow == nil
        self.requestWindow = requestWindow
        let url = pending.isEmpty ? nil : pending.removeFirst()
        if first { for _ in pending { requestWindow() } }
        return url
    }

    /// Window `id` is empty and opens a file with `open`; nil when it has a document or has closed.
    public func setEmpty(_ id: UUID, open: (@MainActor (URL) -> Void)?) {
        empty.removeAll { $0.id == id }
        if let open { empty.append((id, open)) }
    }
}

extension View {
    /// Joins this window to `queue`: it takes the oldest waiting file when it appears, and any file while `isEmpty`.
    public func suiteOpenQueue(_ queue: SuiteOpenQueue, isEmpty: Bool, open: @escaping @MainActor (URL) -> Void)
        -> some View
    {
        modifier(SuiteOpenQueueTaker(queue: queue, isEmpty: isEmpty, open: open))
    }
}

private struct SuiteOpenQueueTaker: ViewModifier {
    let queue: SuiteOpenQueue
    let isEmpty: Bool
    let open: @MainActor (URL) -> Void
    @State private var id = UUID()
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .task {
                let openWindow = openWindow
                let windowID = queue.windowID
                if let url = queue.windowAppeared(requestWindow: { openWindow(id: windowID) }) { open(url) }
            }
            .onChange(of: isEmpty, initial: true) { _, isEmpty in queue.setEmpty(id, open: isEmpty ? open : nil) }
            .onDisappear { queue.setEmpty(id, open: nil) }
    }
}
