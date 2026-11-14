// PointerClick.swift: the click count the window server stamped on the click being handled, for a tap that tells
// a double-click from a single one by the event itself, never by a timed `TapGesture(count: 2)`: SwiftUI times
// those taps by when it handles them, so a busy main thread splits a double-click (#6217), and on a List row the
// timed tap also takes the List's own selection click (#2496). Read it inside a tap's action.
import AppKit

@MainActor enum PointerClick {
    /// The current mouse event's click count; 1 when the action isn't a click (an accessibility action). AppKit
    /// raises on `clickCount` of a non-mouse event, so the type is checked first.
    static func count() -> Int {
        guard let event = NSApp.currentEvent, event.type == .leftMouseUp || event.type == .leftMouseDown else { return 1 }
        return event.clickCount
    }
}
