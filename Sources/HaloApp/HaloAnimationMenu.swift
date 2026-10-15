// HaloAnimationMenu.swift: Halo's Animation menu: Play/Pause, Loop, Next
// Frame, Previous Frame, Go to Start, Go to End, Set In Point, Set Out Point
// and Keyframe Easing ▸ (Linear, Ease In, Ease Out, Ease In and Out, Hold).
// Space, →, ←, Home, End, I and O do the same while the viewer or timeline
// has focus; the items name those keys in their help rather than take them as
// key equivalents, so typing in a field never plays or sets a point. Each item
// is sent through the focused window and disabled with the Model's reason as
// help (HaloMenuItem).
import HaloModel
import SwiftUI

struct HaloAnimationMenu: Commands {
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandMenu("Animation") {
            HaloMenuItem(command: .playPause, target: target, systemImage: "playpause", key: "Space")
            HaloMenuItem(command: .toggleLoop, target: target, systemImage: "repeat")
            Divider()
            HaloMenuItem(command: .nextFrame, target: target, key: "→")
            HaloMenuItem(command: .previousFrame, target: target, key: "←")
            HaloMenuItem(command: .goToStart, target: target, key: "Home")
            HaloMenuItem(command: .goToEnd, target: target, key: "End")
            Divider()
            HaloMenuItem(command: .setInPoint, target: target, key: "I")
            HaloMenuItem(command: .setOutPoint, target: target, key: "O")
            Divider()
            Menu("Keyframe Easing") {
                ForEach(HaloEasingPreset.allCases, id: \.self) { preset in
                    HaloMenuItem(command: .setEasing(preset), target: target)
                }
            }
        }
    }
}
