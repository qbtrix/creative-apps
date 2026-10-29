// DesignInspectorKey.swift: the key button beside the X, Y and Opacity rows of Design's inspector, SuiteUI's
// KeyframeButton over the Model's `keyState` at the playhead. The stopwatch runs `keyAnimate` (animate the row from
// the playhead to the last frame, or leave one held key), the diamond `keyToggle` (set or remove the key at the
// playhead), both as keyframe.set and keyframe.remove through `.keys`. One selected layer only; off with the row's
// own reason. KeyframeButton sets its own identifiers (`design.inspector.key.<property>` and its diamond's), so
// nothing may wrap the pair in an identifier or a `.help` (#1282); both are only listed in `suite.controls` here.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct DesignKeyButton: View {
    let model: DesignWorkspace
    let property: DesignKeyProperty
    /// Why the row can't edit (a locked layer), which also turns the key button off.
    let help: String?
    let perform: DesignPerform

    var body: some View {
        if let id = model.selectedNode?.id, let state = model.keyState(id, property) {
            let key = "design.inspector.key.\(property.rawValue)"
            let shown = Self.state(state)
            KeyframeButton(
                property == .opacity ? "Opacity" : property.rawValue.uppercased(), id: key, state: shown,
                unavailableHelp: help,
                onToggle: { if let commands = model.keyAnimate(id, property) { perform(.keys(commands)) } },
                onKey: { if let command = model.keyToggle(id, property) { perform(.keys([command])) } })
                .disabled(help != nil)
                .suiteControl(id: key, enabled: help == nil, reason: help, identifies: false)
                .suiteControl(
                    id: shown.diamond == nil ? nil : KeyframeButton.diamondID(key), enabled: help == nil, reason: help,
                    identifies: false)
        }
    }

    /// SuiteUI's stopwatch state for the kernel's key state, one to one.
    static func state(_ state: SuiteKernel.KeyState) -> SuiteUI.KeyState {
        switch state {
        case .notAnimated: .idle
        case .animated: .animated
        case .keyedHere: .keyedHere
        }
    }
}
