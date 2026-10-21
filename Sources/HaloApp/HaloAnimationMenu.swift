// HaloAnimationMenu.swift: Halo's Animation menu: Play/Pause, Loop, Next
// Frame, Previous Frame, Go to Start, Go to End, Set In Point, Set Out Point
// and Keyframe Easing ▸ (Linear, Ease In, Ease Out, Ease In and Out, Hold),
// then Select All Keys (⌘A in the timeline, not a key equivalent here so a
// field keeps ⌘A) and Move Keyframes Left and Right, each one frame and its
// own step (nudgeKeysCommands), disabled with the Model's reason (KE-2).
// Space, →, ←, Home, End, I and O do the same while the viewer or timeline
// has focus; the items don't take those keys as key equivalents, so typing in
// a field never plays or sets a point. Each item is built from its catalog
// spec (HaloMenuTarget.item), sent through the focused window and disabled
// with the spec's reason as help.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloAnimationMenu: Commands {
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandMenu("Animation") {
            target.item(.playPause, systemImage: "playpause")
            target.item(.toggleLoop, systemImage: "repeat")
            Divider()
            target.item(.nextFrame)
            target.item(.previousFrame)
            target.item(.goToStart)
            target.item(.goToEnd)
            Divider()
            target.item(.setInPoint)
            target.item(.setOutPoint)
            Divider()
            Menu("Keyframe Easing") {
                ForEach(HaloEasingPreset.allCases, id: \.self) { preset in
                    target.item(.setEasing(preset))
                }
            }
            Divider()
            keyItem("Select All Keys", .selectAllKeys, help: "Picks every key in the timeline; ⌘A there does the same.") {
                perform?(.selectAllKeys)
            }
            nudge("Move Keyframes Left", by: -1)
            nudge("Move Keyframes Right", by: 1)
        }
    }

    /// A one-frame move of the picked keys, its own undo step.
    private func nudge(_ title: String, by frames: Int) -> MenuCommand {
        keyItem(title, .moveKeys(by: frames, dragStart: 0), help: "Moves the picked keys \(abs(frames)) frame.") {
            for command in model?.nudgeKeysCommands(by: frames) ?? [] { perform?(command) }
        }
    }

    /// An item disabled with the Model's reason while `command` can't act, else `help`.
    private func keyItem(
        _ title: String, _ command: HaloCommand, help: String, action: @escaping @MainActor () -> Void
    ) -> MenuCommand {
        let reason = target.help(for: command)
        return MenuCommand(title, help: reason ?? help, isEnabled: reason == nil, perform: action)
    }
}
