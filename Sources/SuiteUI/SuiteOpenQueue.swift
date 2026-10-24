// SuiteOpenQueue.swift: what waits for one of an app's windows (a file
// dropped or handed off, File > Open Recent ▸, Open In from another app, or
// Photo's new image). An empty window takes the item in place, as a document
// app's untitled window does; else a new window of the app's
// `WindowGroup(id:)` is asked for and takes the oldest waiting item when it
// appears. A window that takes an item stops counting as empty at once, so a
// second item never lands on top of the first. Windows join through
// `suiteOpenQueue(_:isEmpty:open:)`.
//
// Asking for a window needs an `openWindow`. A window hands over its own when
// it appears, and the scene's commands hand over theirs at launch
// (`Scene.suiteOpenQueue(_:)`, `appLaunched`), because a cold launch with a
// file (Finder, `open -a`, a hand-off from the home) gets no first window. The
// first opener to arrive asks for one window per item already waiting; later
// ones only replace it, so nothing is asked for twice. Without the commands'
// opener the first window to appear does that asking instead.
import SwiftUI

@MainActor public final class SuiteOpenQueue<Item> {
    public let windowID: String
    private var pending: [Item] = []
    /// Asks for a new window; nil until a window appears or the scene's commands hand theirs over.
    private var requestWindow: (@MainActor () -> Void)?
    /// The empty windows, oldest first, each with its own open.
    private var empty: [(id: UUID, open: @MainActor (Item) -> Void)] = []

    public init(windowID: String, items: Item.Type) { self.windowID = windowID }

    /// Opens `item` in an empty window, else in a new one.
    public func open(_ item: Item) {
        if !empty.isEmpty {
            empty.removeFirst().open(item)
            return
        }
        pending.append(item)
        requestWindow?()
    }

    /// The app can open a window with none on screen: asks for one per waiting item if nothing has asked yet.
    public func appLaunched(requestWindow: @escaping @MainActor () -> Void) {
        adopt(requestWindow)
    }

    /// A window appeared: the oldest item waiting for it, or nil.
    public func windowAppeared(requestWindow: @escaping @MainActor () -> Void) -> Item? {
        let item = pending.isEmpty ? nil : pending.removeFirst()
        adopt(requestWindow)
        return item
    }

    /// Window `id` is empty and opens an item with `open`; nil when it has a document or has closed.
    public func setEmpty(_ id: UUID, open: (@MainActor (Item) -> Void)?) {
        empty.removeAll { $0.id == id }
        if let open { empty.append((id, open)) }
    }

    /// Keeps `opener`; the first one also asks for a window per item still waiting.
    private func adopt(_ opener: @escaping @MainActor () -> Void) {
        let first = requestWindow == nil
        requestWindow = opener
        if first { for _ in pending { opener() } }
    }
}

extension SuiteOpenQueue where Item == URL {
    public convenience init(windowID: String) { self.init(windowID: windowID, items: URL.self) }
}

extension Scene {
    /// Hands `queue` an opener at launch, so a file that cold-launches the app opens a window even if none appears.
    @MainActor public func suiteOpenQueue<Item>(_ queue: SuiteOpenQueue<Item>) -> some Scene {
        commands { SuiteOpenQueueLauncher(queue: queue) }
    }
}

/// The scene's `openWindow`, which works with no window open, given to the queue once the menus are built.
private struct SuiteOpenQueueLauncher<Item>: Commands {
    let queue: SuiteOpenQueue<Item>
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        let openWindow = openWindow
        let queue = queue
        // Off the menu build: opening a window while SwiftUI builds the commands is a state change mid-update.
        Task { @MainActor in queue.appLaunched(requestWindow: { openWindow(id: queue.windowID) }) }
        return EmptyCommands()
    }
}

extension View {
    /// Joins this window to `queue`: it takes the oldest waiting item when it appears, and any item while `isEmpty`.
    public func suiteOpenQueue<Item>(
        _ queue: SuiteOpenQueue<Item>, isEmpty: Bool, open: @escaping @MainActor (Item) -> Void
    ) -> some View {
        modifier(SuiteOpenQueueTaker(queue: queue, isEmpty: isEmpty, open: open))
    }
}

private struct SuiteOpenQueueTaker<Item>: ViewModifier {
    let queue: SuiteOpenQueue<Item>
    let isEmpty: Bool
    let open: @MainActor (Item) -> Void
    @State private var id = UUID()
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .task {
                let openWindow = openWindow
                let windowID = queue.windowID
                if let item = queue.windowAppeared(requestWindow: { openWindow(id: windowID) }) { open(item) }
            }
            .onChange(of: isEmpty, initial: true) { _, isEmpty in queue.setEmpty(id, open: isEmpty ? open : nil) }
            .onDisappear { queue.setEmpty(id, open: nil) }
    }
}
