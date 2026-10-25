// SuiteOpenQueue.swift: files waiting for one of an app's windows (a dropped
// file, File > Open Recent ▸, Open In from another app), and new documents a
// `.new` hand-off asks for (the home's New tile, the welcome's presets). An
// empty window takes a request in place, as a document app's untitled window
// does; else a new window of the app's `WindowGroup(id:)` is asked for and
// takes the oldest waiting request when it appears. The first window to appear
// also asks for one per request that came before any window could. A window
// that takes a request stops counting as empty at once, so a second never
// lands on top of the first. Windows join through
// `suiteOpenQueue(_:isEmpty:open:newDocument:)`.
import SwiftUI

/// What a window is asked to show: a file, or a new document.
public enum SuiteOpenRequest: Equatable, Sendable {
    case file(URL)
    case newDocument
}

@MainActor public final class SuiteOpenQueue {
    public let windowID: String
    private var pending: [SuiteOpenRequest] = []
    /// Asks for a new window (the first window's `openWindow`); nil until a window appears.
    private var requestWindow: (@MainActor () -> Void)?
    /// The empty windows, oldest first, each with its own open.
    private var empty: [(id: UUID, open: @MainActor (SuiteOpenRequest) -> Void)] = []

    public init(windowID: String) { self.windowID = windowID }

    /// Opens `url` in an empty window, else in a new one.
    public func open(_ url: URL) { take(.file(url)) }

    /// Starts a new document in an empty window, else in a new one.
    public func openNew() { take(.newDocument) }

    private func take(_ request: SuiteOpenRequest) {
        if !empty.isEmpty {
            empty.removeFirst().open(request)
            return
        }
        pending.append(request)
        requestWindow?()
    }

    /// A window appeared: the oldest request waiting for it, or nil.
    public func windowAppeared(requestWindow: @escaping @MainActor () -> Void) -> SuiteOpenRequest? {
        let first = self.requestWindow == nil
        self.requestWindow = requestWindow
        let request = pending.isEmpty ? nil : pending.removeFirst()
        if first { for _ in pending { requestWindow() } }
        return request
    }

    /// Window `id` is empty and takes a request with `open`; nil when it has a document or has closed.
    public func setEmpty(_ id: UUID, open: (@MainActor (SuiteOpenRequest) -> Void)?) {
        empty.removeAll { $0.id == id }
        if let open { empty.append((id, open)) }
    }
}

extension View {
    /// Joins this window to `queue`: it takes the oldest waiting request when it appears, and any
    /// request while `isEmpty`. A file goes to `open`, a new document to `newDocument`.
    public func suiteOpenQueue(
        _ queue: SuiteOpenQueue, isEmpty: Bool, open: @escaping @MainActor (URL) -> Void,
        newDocument: @escaping @MainActor () -> Void = {}
    ) -> some View {
        modifier(SuiteOpenQueueTaker(queue: queue, isEmpty: isEmpty) { request in
            switch request {
            case .file(let url): open(url)
            case .newDocument: newDocument()
            }
        })
    }
}

private struct SuiteOpenQueueTaker: ViewModifier {
    let queue: SuiteOpenQueue
    let isEmpty: Bool
    let open: @MainActor (SuiteOpenRequest) -> Void
    @State private var id = UUID()
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .task {
                let openWindow = openWindow
                let windowID = queue.windowID
                if let request = queue.windowAppeared(requestWindow: { openWindow(id: windowID) }) { open(request) }
            }
            .onChange(of: isEmpty, initial: true) { _, isEmpty in queue.setEmpty(id, open: isEmpty ? open : nil) }
            .onDisappear { queue.setEmpty(id, open: nil) }
    }
}
