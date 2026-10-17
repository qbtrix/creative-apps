// SuiteWindowSizer.swift: `-SuiteWindowSize WxH` (both above zero, else nil)
// opens a SuiteWindow at that frame size. Only with the flag, SuiteWindow puts
// a SuiteWindowSizer behind its body; in a window it calls `setFrame(_:display:)`
// once, top edge kept, fitted to the screen's visible frame (so 1024x768 on a
// 1024x768 display comes out a little shorter), with frame autosave and
// restoration off so the size never carries into a plain launch. The visible
// frame moves while an app launches (the Dock resizes for its tile, a few
// points at a time; #1778: a window fitted at launch sat 3 pt into the Dock
// when the journey measured it), so the sizer fits the window again whenever
// the screen parameters change and once more a second after launch. A fit
// only ever shrinks or moves the window; `SuiteWindowSize.fitted` is the math.
import AppKit
import SwiftUI

/// The launch argument that sizes a SuiteWindow.
public enum SuiteWindowSize {
    public static let flag = "-SuiteWindowSize"

    /// The size after `-SuiteWindowSize` ("1024x768"); nil when the flag is
    /// missing, has no value, or its value isn't two positive numbers.
    public static func parse(_ arguments: [String]) -> CGSize? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        let parts = arguments[index + 1].split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]),
              width.isFinite, height.isFinite, width > 0, height > 0
        else { return nil }
        return CGSize(width: width, height: height)
    }

    /// `frame` inside `visible`: no wider or taller than it, moved the least
    /// that puts the whole frame inside it. A frame already inside is
    /// unchanged, and so is any frame when `visible` is empty or not finite.
    /// Pure rectangle math, so it holds in either screen coordinate system.
    public static func fitted(_ frame: CGRect, in visible: CGRect) -> CGRect {
        guard visible.width > 0, visible.height > 0, visible.width.isFinite, visible.height.isFinite,
              visible.minX.isFinite, visible.minY.isFinite
        else { return frame }
        let size = CGSize(width: min(frame.width, visible.width), height: min(frame.height, visible.height))
        let origin = CGPoint(
            x: min(max(frame.minX, visible.minX), visible.maxX - size.width),
            y: min(max(frame.minY, visible.minY), visible.maxY - size.height))
        return CGRect(origin: origin, size: size)
    }
}

/// An invisible background that gives its window the requested frame size once.
struct SuiteWindowSizer: NSViewRepresentable {
    let size: CGSize

    func makeNSView(context: Context) -> SuiteWindowSizingView { SuiteWindowSizingView(requested: size) }

    func updateNSView(_ nsView: SuiteWindowSizingView, context: Context) {}
}

/// Applies its requested size to the first window it joins, on the next main-actor turn
/// so the window has finished placing itself first, then keeps that window inside the
/// screen's visible frame as the frame changes.
final class SuiteWindowSizingView: NSView {
    private let requested: CGSize
    private var done = false

    init(requested: CGSize) {
        self.requested = requested
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if done || window == nil { return }
        done = true
        // A selector observer is unregistered when the view goes away (macOS 10.11 and later).
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        Task { @MainActor [weak self] in
            self?.applySize()
            try? await Task.sleep(for: .seconds(1))
            self?.refit()
        }
    }

    private func applySize() {
        guard let target = window else { return }
        _ = target.setFrameAutosaveName("")
        target.isRestorable = false
        let current = target.frame
        let frame = NSRect(origin: NSPoint(x: current.minX, y: current.maxY - requested.height), size: requested)
        target.setFrame(Self.fitted(frame, to: target), display: true)
    }

    /// The Dock or the menu bar changed the visible frame (the system posts this on the main actor).
    @objc private func screenParametersChanged(_ notification: Notification) {
        refit()
    }

    /// Moves or shrinks the window the least that keeps it inside its screen's visible frame.
    private func refit() {
        guard let target = window else { return }
        let frame = Self.fitted(target.frame, to: target)
        if frame != target.frame { target.setFrame(frame, display: true) }
    }

    /// `frame` fitted to the visible frame of `window`'s screen (the main screen before it has one).
    private static func fitted(_ frame: NSRect, to window: NSWindow) -> NSRect {
        guard let visible = (window.screen ?? NSScreen.main)?.visibleFrame else { return frame }
        return SuiteWindowSize.fitted(frame, in: visible)
    }
}
