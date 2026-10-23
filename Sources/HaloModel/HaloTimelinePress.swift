// HaloTimelinePress.swift (key-editing KE-2): what a press, a key drag and a
// menu nudge on Halo's timeline send. The strip names a press's mode
// ("replace" plain, "extend" with Shift, "toggle" with Command); a key press
// picks its lane's keys in that mode and a bed press (a nil frame) clears the
// pick. While key picking can't act a key press selects its layer instead and
// a bed press sends nothing, since the strip's track press already selected
// it. A drag's moves fold under the first picked frame, and Animation >
// Move Keyframes Left or Right is one move and its end, so each is its own
// step. Linux-safe: no UI imports.
import SuiteKernel

extension HaloProject {
    /// The command a press on `layerID`'s lane at `frame` sends in the
    /// strip's `mode`; nil when there is nothing to send.
    public func lanePressCommand(layerID: String, frame: Int?, mode: String) -> HaloCommand? {
        let pick = HaloCommand.pickLaneKeys(layerID: layerID, frame: frame, mode: Self.pick(named: mode))
        if unavailableHelp(for: pick) == nil { return pick }
        return frame == nil ? nil : .selectLayer(layerID)
    }

    /// The pick a strip mode names; anything unknown replaces.
    static func pick(named name: String) -> Pick {
        switch name {
        case "extend": .extend
        case "toggle": .toggle
        default: .replace
        }
    }

    /// The `dragStart` a key drag beginning now sends: the first picked frame.
    public var keyDragStart: Int { pickedKeyframes.map(\.frame).min() ?? 0 }

    /// What a menu nudge sends: one move by `frames` and its end.
    public func nudgeKeysCommands(by frames: Int) -> [HaloCommand] {
        [.moveKeys(by: frames, dragStart: keyDragStart), .endKeyDrag]
    }
}
