// FlareWindow+Timeline.swift: the window's `.timeline` intents: transport, and the key, frame and label edits of
// IT-7. `timelineHelp(_:in:)` says why one can't run, for the menus and FlareTimelineEdit's context menu.
import FlareModel

extension FlareWindow {
    func performTimeline(_ intent: FlareIntent.Timeline) {
        switch intent {
        case .scrub(let frame): model.setCurrentFrame(frame)
        case .goToStart: model.goToStart()
        case .goToEnd: model.goToEnd()
        case .step(let delta): model.stepFrame(by: delta)
        case .togglePlay: model.togglePlay()
        case .setLoops(let on): model.setLoops(on)
        case .toggleAutoKey: model.toggleAutoKey()
        case .selectKey(let layerID, let property, let frame, let extending):
            model.selectKey(KeyRef(layerID: layerID, property: property, frame: frame), extending: extending)
        case .moveKeys(let frames, let dragStart): model.moveSelectedKeys(by: frames, dragStart: dragStart)
        case .endKeyDrag: model.endKeyDrag()
        case .removeKeys: model.removeSelectedKeys()
        case .insertFrames(let count): model.insertFrames(count)
        case .removeFrames(let count): model.removeFrames(count)
        case .setLabel(let name): model.setLabel(name)
        case .nextKeyframe, .previousKeyframe, .addKey, .removeKey:
            break
        }
    }

    func timelineHelp(_ intent: FlareIntent.Timeline) -> String? { Self.timelineHelp(intent, in: model) }

    /// Why `intent` can't run on `model`; nil when it can.
    static func timelineHelp(_ intent: FlareIntent.Timeline, in model: FlareWorkspace) -> String? {
        let noDocument = model.document == nil ? "Open an animation to edit its timeline." : nil
        switch intent {
        case .scrub, .togglePlay, .setLoops: return model.canPlay ? nil : FlareTransport.cannotPlay
        case .goToStart, .goToEnd, .step: return FlareTransport.help(for: intent, in: model)
        case .toggleAutoKey: return model.document == nil ? "Open an animation to key it." : nil
        case .selectKey, .insertFrames, .removeFrames: return noDocument
        case .moveKeys, .removeKeys: return noDocument ?? (model.selectedKeys.isEmpty ? FlareWorkspace.selectKeyFirst : nil)
        case .endKeyDrag: return nil
        case .setLabel(let name?): return noDocument ?? (name.isEmpty ? "Name the label first." : nil)
        // The Animate menu's Add Label sends no name, so it points at the context menu, which asks for one.
        case .setLabel(nil): return noDocument ?? "Name a label from the timeline's context menu (Add Label…)."
        case .nextKeyframe, .previousKeyframe, .addKey, .removeKey: return "Not built yet (F7a)."
        }
    }
}
