// HaloAnimationMenu.swift: Halo's Animation menu: Play/Pause, Loop, Next
// Frame, Previous Frame, Go to Start, Go to End, Set In Point, Set Out Point
// and Keyframe Easing ▸ (SuiteKernel's six presets: Linear, Ease, Ease In, Ease Out, Ease In-Out, Hold),
// then Select All Keys (⌘A in the timeline, not a key equivalent here so a
// field keeps ⌘A) and Move Keyframes Left and Right, each one frame and its
// own step (nudgeKeysCommands), disabled with the Model's reason (KE-2).
// Space, →, ←, Home, End, I and O do the same while the viewer or timeline
// has focus; the items don't take those keys as key equivalents, so typing in
// a field never plays or sets a point. Each item is built from its catalog
// spec (HaloMenuTarget.item), sent through the focused window and disabled
// with the spec's reason as help.
import HaloModel
import SuiteKernel
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
                ForEach(EasePreset.allCases, id: \.self) { preset in
                    target.item(.setEasing(preset))
                }
            }
            Divider()
            target.item(.selectAllKeys)
            nudge("Move Keyframes Left", by: -1)
            nudge("Move Keyframes Right", by: 1)
        }
    }

    /// A one-frame move of the picked keys, its own undo step, on the Move Keyframes spec.
    private func nudge(_ title: String, by frames: Int) -> MenuCommand {
        let spec = HaloMenuState.spec(HaloCommand.moveKeys(by: frames, dragStart: 0).commandID)
        return MenuCommand(spec, on: target.state, title: title) {
            for command in model?.nudgeKeysCommands(by: frames) ?? [] { perform?(command) }
        }
    }
}
