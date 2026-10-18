// HaloAnimationMenu.swift: Halo's Animation menu: Play/Pause, Loop, Next
// Frame, Previous Frame, Go to Start, Go to End, Set In Point, Set Out Point
// and Keyframe Easing ▸ (Linear, Ease In, Ease Out, Ease In and Out, Hold).
// Space, →, ←, Home, End, I and O do the same while the viewer or timeline
// has focus; the items name those keys in their help rather than take them as
// key equivalents, so typing in a field never plays or sets a point. Each item
// is sent through the focused window and disabled with the Model's reason as
// help (SuiteUI's MenuCommand).
import HaloModel
import SuiteUI
import SwiftUI

struct HaloAnimationMenu: Commands {
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandMenu("Animation") {
            MenuCommand(command: .playPause, target: target, systemImage: "playpause", key: "Space")
            MenuCommand(command: .toggleLoop, target: target, systemImage: "repeat")
            Divider()
            MenuCommand(command: .nextFrame, target: target, key: "→")
            MenuCommand(command: .previousFrame, target: target, key: "←")
            MenuCommand(command: .goToStart, target: target, key: "Home")
            MenuCommand(command: .goToEnd, target: target, key: "End")
            Divider()
            MenuCommand(command: .setInPoint, target: target, key: "I")
            MenuCommand(command: .setOutPoint, target: target, key: "O")
            Divider()
            Menu("Keyframe Easing") {
                ForEach(HaloEasingPreset.allCases, id: \.self) { preset in
                    MenuCommand(command: .setEasing(preset), target: target)
                }
            }
        }
    }
}
