// PointerPressure.swift: the pen pressure behind the canvas's brush drags.
// SwiftUI's drag gesture carries no pressure, so this watches the app's own
// left-button mouse events through a local AppKit event monitor (it reads
// them and passes every one on) and keeps the latest one's pressure: a tablet
// pen's NSEvent.pressure, and 1 for a mouse or trackpad, so they paint at a
// constant width. A pen can touch down with pressure near 0, so a stroke may
// start at the brush's thinnest and widen. Presentation state only:
// PhotoWindow passes `current` to the model's drag.
import AppKit

@MainActor enum PointerPressure {
    /// The latest left-button event's pressure, 0...1.
    private(set) static var current = 1.0
    private static var monitor: Any?

    /// Starts watching; later calls do nothing.
    static func watch() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) {
            event in
            // Mouse events always have a subtype; a tablet pen's say so.
            let pressure = event.subtype == .tabletPoint ? Double(event.pressure) : 1
            MainActor.assumeIsolated { current = pressure }
            return event
        }
    }
}
