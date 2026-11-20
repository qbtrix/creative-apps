// ScrubKeyMonitor.swift: a focused ScrubField takes its own keys before the
// menu bar does. AppKit matches a menu item's key equivalent before the
// focused view's keyDown, so a bare-key item (Flare's Animate > Next Frame on
// →, Go to Start on Home, Play on Space) took the arrows from a focused
// inspector bar, which then never stepped (Flare J7). While the field holds
// the keyboard in the key window and isn't typing, ScrubField watches it: a
// local key-down monitor runs before the menu, and the keys `press(for:)`
// names (arrows, Home, End, Space, with no ⌘ or ⌃) go to the field and stop
// there. Return is left alone, so a sheet's default button keeps it; the
// field's own key press still opens its typing field on Return. `handle` is refreshed by every
// ScrubField body, so a press reads the value the field shows now.
import AppKit

@MainActor final class ScrubKeyMonitor {
    /// What a key does on a focused field: step it, or open its typing field.
    enum Press: Equatable, Sendable {
        case step(ScrubKey, shift: Bool, option: Bool)
        case type
    }

    /// The field's own handling of `press`; true when it took the key.
    var handle: @MainActor (Press) -> Bool = { _ in false }
    private var monitor: Any?

    /// Watches key-downs while `on`, else stops.
    func watch(_ on: Bool) {
        if on, monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let press = Self.press(for: event.specialKey, characters: event.charactersIgnoringModifiers,
                                       flags: event.modifierFlags)
                guard let press else { return event }
                let taken = MainActor.assumeIsolated { self?.handle(press) ?? false }
                return taken ? nil : event
            }
        } else if !on, let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    /// The field's press for a key-down, nil for a key it leaves alone (⌘ or ⌃ held, or not one of its keys).
    nonisolated static func press(
        for special: NSEvent.SpecialKey?, characters: String?, flags: NSEvent.ModifierFlags
    ) -> Press? {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        guard flags.isDisjoint(with: [.command, .control]) else { return nil }
        let (shift, option) = (flags.contains(.shift), flags.contains(.option))
        switch special {
        case .upArrow?, .rightArrow?: return .step(.increment, shift: shift, option: option)
        case .downArrow?, .leftArrow?: return .step(.decrement, shift: shift, option: option)
        case .home?: return .step(.home, shift: shift, option: option)
        case .end?: return .step(.end, shift: shift, option: option)
        default: return characters == " " ? .type : nil
        }
    }
}
