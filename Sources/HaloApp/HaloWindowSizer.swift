// HaloWindowSizer.swift: `-HaloWindowSize` made to stick. `.defaultSize`
// only sizes a window that has no saved frame, and a WindowGroup saves its
// window's frame between launches whatever `-ApplePersistenceIgnoreState`
// says, so a journey that relaunches Halo at another size got the last run's
// frame back. Under `-HaloWindowSize` HaloApp puts this invisible view behind
// the window's content; once it is in a window it sets that window's frame to
// the requested size, top left kept, both held to the screen's visible frame
// (a size larger than the display shrinks to it), after turning
// off that window's frame autosave and restoration so the size never leaks
// into a later launch (a 880 pt layout run once opened every later journey
// at 880). Without the
// flag nothing is added and the saved frame or the default size rules.
import AppKit
import SwiftUI

struct HaloWindowSizer: NSViewRepresentable {
    let size: CGSize

    func makeNSView(context: Context) -> HaloWindowSizingView { HaloWindowSizingView(size: size) }

    func updateNSView(_ view: HaloWindowSizingView, context: Context) {}
}

/// Sizes the first window it moves into, once, after the window has placed itself.
final class HaloWindowSizingView: NSView {
    private let size: CGSize
    private var sized = false

    init(size: CGSize) {
        self.size = size
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !sized, window != nil else { return }
        sized = true
        // On the next turn of the main actor, after the window restored any saved frame.
        Task { @MainActor in self.resizeWindow() }
    }

    private func resizeWindow() {
        guard let window else { return }
        // A sized launch is a one-off: the window stops autosaving its frame
        // and isn't restorable before it resizes, so the next plain launch
        // opens at the saved or default size, never at this one.
        _ = window.setFrameAutosaveName("")
        window.isRestorable = false
        let top = window.frame.maxY
        var frame = NSRect(x: window.frame.minX, y: top - size.height, width: size.width, height: size.height)
        // constrainFrameRect(_:to:) only keeps the top edge on the screen, so
        // a 1280 pt window ran 256 pt off the runner's 1024 pt display: the
        // size is held to the screen's visible frame and the window moved on.
        if let visible = window.screen?.visibleFrame {
            frame.size = CGSize(width: min(frame.width, visible.width), height: min(frame.height, visible.height))
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(top - frame.height, visible.minY), visible.maxY - frame.height)
        }
        window.setFrame(frame, display: true)
    }
}
