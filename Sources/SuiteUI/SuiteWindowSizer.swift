// SuiteWindowSizer.swift: `-SuiteWindowSize WxH` (both above zero, else nil)
// opens a SuiteWindow at that frame size. Only with the flag, SuiteWindow puts
// a SuiteWindowSizer behind its body; in a window it calls `setFrame(_:display:)`
// once, top edge kept, fitted to the screen's visible frame (so 1024x768 on a
// 1024x768 display comes out a little shorter), with frame autosave and
// restoration off so the size never carries into a plain launch.
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
}

/// An invisible background that gives its window the requested frame size once.
struct SuiteWindowSizer: NSViewRepresentable {
    let size: CGSize

    func makeNSView(context: Context) -> SuiteWindowSizingView { SuiteWindowSizingView(requested: size) }

    func updateNSView(_ nsView: SuiteWindowSizingView, context: Context) {}
}

/// Applies its requested size to the first window it joins, on the next main-actor turn
/// so the window has finished placing itself first.
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
        Task { @MainActor [weak self] in self?.applySize() }
    }

    private func applySize() {
        guard let target = window else { return }
        _ = target.setFrameAutosaveName("")
        target.isRestorable = false
        let current = target.frame
        var frame = NSRect(
            origin: NSPoint(x: current.minX, y: current.maxY - requested.height), size: requested)
        if let visible = (target.screen ?? NSScreen.main)?.visibleFrame {
            frame.size.width = min(frame.width, visible.width)
            frame.size.height = min(frame.height, visible.height)
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(current.maxY - frame.height, visible.minY), visible.maxY - frame.height)
        }
        target.setFrame(frame, display: true)
    }
}
