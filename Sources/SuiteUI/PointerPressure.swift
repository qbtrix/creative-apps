// PointerPressure.swift: pen pressure for a canvas drag (EK-30; Photo's shape).
// `watch()` monitors left-button events once and keeps the latest reading: a
// pen's pressure clamped to 0...1, and 1 for a mouse or trackpad.
import AppKit

@MainActor public enum PointerPressure {
    public private(set) static var current = 1.0
    private static var monitor: Any?

    public nonisolated static func reading(isPen: Bool, raw: Float) -> Double {
        guard isPen, !raw.isNaN else { return 1 }
        return min(max(Double(raw), 0), 1)
    }

    public static func watch() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { event in
            let value = reading(isPen: event.subtype == .tabletPoint, raw: event.pressure)
            MainActor.assumeIsolated { current = value }
            return event
        }
    }
}
