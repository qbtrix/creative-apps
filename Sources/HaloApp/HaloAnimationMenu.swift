// HaloAnimationMenu.swift: Halo's Animation menu: Play/Pause, Loop, Next
// Frame, Previous Frame, Go to Start, Go to End, Set In Point, Set Out Point
// and Keyframe Easing ▸ (Linear, Ease In, Ease Out, Ease In and Out, Hold).
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
        }
    }
}
