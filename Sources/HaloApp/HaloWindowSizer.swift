// HaloWindowSizer.swift: `-HaloWindowSize` made to stick. `.defaultSize`
// only sizes a window that has no saved frame, and a WindowGroup saves its
// window's frame between launches whatever `-ApplePersistenceIgnoreState`
// says, so a journey that relaunches Halo at another size got the last run's
// frame back. Under `-HaloWindowSize` HaloApp puts this invisible view behind
// the window's content; once it is in a window it sets that window's frame to
// the requested size, top left kept, constrained to the screen, after turning
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
        if let screen = window.screen { frame = window.constrainFrameRect(frame, to: screen) }
        window.setFrame(frame, display: true)
    }
}
