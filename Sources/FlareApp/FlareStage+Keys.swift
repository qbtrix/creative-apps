// FlareStage+Keys.swift (brush-keys BK-12): the stage's digit keys. ToolKeys.brushAction reads a digit by the kernel's
// BrushKeys rule (none while a text field types, or with ⌘ or ⌥ held); Flare has no brush, so a digit is the selected
// layers' opacity, sent as the inspector's opacity edit (FlareWorkspace.opacityIntents). 1 is 10%, 0 is 100%, 4 then
// 5 quickly is 45%. The digit buffer is a box the body never reads, so a press runs no stage body.
import AppKit
import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// The opacity digits typed so far, for every Flare stage.
@MainActor final class FlareOpacityKeyBuffer {
    static let shared = FlareOpacityKeyBuffer()
    var digits = OpacityDigits()
}

extension FlareStage {
    /// `press` as a digit's opacity edit: handled once sent, nil for a key that isn't one.
    func opacityKey(_ press: KeyPress) -> KeyPress.Result? {
        let pairs: [(EventModifiers, KeyModifiers)] = [(.shift, .shift), (.option, .option), (.command, .command)]
        let held = pairs.reduce(into: KeyModifiers()) { mods, pair in if press.modifiers.contains(pair.0) { mods.insert(pair.1) } }
        let buffer = FlareOpacityKeyBuffer.shared
        guard case .layerOpacity(let percent) = ToolKeys.brushAction(
            forKey: press.characters, modifiers: held, at: ProcessInfo.processInfo.systemUptime,
            firstResponder: NSApplication.shared.keyWindow?.firstResponder, settings: model.activeBrush,
            digits: &buffer.digits)
        else { return nil }
        FlareWorkspace.opacityIntents(percent).forEach(perform)
        return .handled
    }
}
