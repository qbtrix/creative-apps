// FlareWindow+Inspector.swift: the router's inspector area
// (FlareWindow+Router.swift). Every `.inspector` intent goes to its Model
// call; `inspectorHelp(_:in:)` says why one can't act, and the inspector's
// rows read the same reason the menus do.
import FlareCore
import FlareModel

extension FlareWindow {
    /// Acts on an inspector intent.
    func performInspector(_ intent: FlareIntent.Inspector) {
        switch intent {
        case .showTab(let id): if let tab = FlareInspectorTab(rawValue: id) { inspectorTab = tab }
        case let .scrub(property, value, start): model.setProperty(property, to: value, dragStart: start)
        case .endScrub: model.endPropertyScrub()
        case .toggleAnimated(let property): model.toggleAnimated(property)
        case .toggleKey(let property): model.toggleKey(property)
        case .setFill(let hex): model.setFill(hex: hex)
        case .setStrokeColor(let hex): model.setStrokeColor(hex: hex)
        case .setStrokeWidth(let width): model.setStrokeWidth(width)
        case .setStrokeCap(let raw): if let cap = Stroke.Cap(rawValue: raw) { model.setStrokeCap(cap) }
        case .setStrokeJoin(let raw): if let join = Stroke.Join(rawValue: raw) { model.setStrokeJoin(join) }
        case let .setSceneSize(width, height):
            if let scene = model.selectedScene { model.setSceneCanvas(width: width, height: height, background: scene.background) }
        case .setSceneBackground(let hex):
            if let scene = model.selectedScene, let color = NewDocumentSpec.color(hex: hex) {
                model.setSceneCanvas(width: scene.width, height: scene.height, background: color)
            }
        case let .setSceneTiming(fps, frames): model.setSceneTiming(fps: fps, durationFrames: frames)
        case .easingPreset(let raw): if let preset = EasingPreset(rawValue: raw) { model.setEasingPreset(preset) }
        case let .easingHandle(index, x, y):
            if let handle = EasingHandle(rawValue: index) { model.moveEasingHandle(handle, to: Point(x: x, y: y)) }
        case .endEasingHandle: model.endEasingHandleDrag()
        }
    }

    /// Why an inspector intent can't act now; nil when it can.
    func inspectorHelp(_ intent: FlareIntent.Inspector) -> String? { Self.inspectorHelp(intent, in: model) }

    /// Why `intent` can't act on `model` now; nil when it can. The inspector's rows read this too.
    static func inspectorHelp(_ intent: FlareIntent.Inspector, in model: FlareWorkspace) -> String? {
        if case .showTab = intent { return nil }
        guard model.selectedScene != nil else { return "Open an animation first." }
        switch intent {
        case .showTab, .endScrub, .endEasingHandle, .setSceneSize, .setSceneTiming: return nil
        case .scrub: return model.propertyLayerIDs.isEmpty ? "Select a layer first." : nil
        case .toggleAnimated, .toggleKey: return model.propertyLayerIDs.count == 1 ? nil : "Select one layer to key it."
        case .setFill, .setStrokeColor, .setStrokeWidth: return model.paint == nil ? "Select a layer to paint it." : nil
        case .setStrokeCap(let raw):
            return model.paint == nil ? "Select a layer to paint it." : Stroke.Cap(rawValue: raw) == nil ? "No cap named \(raw)." : nil
        case .setStrokeJoin(let raw):
            return model.paint == nil ? "Select a layer to paint it." : Stroke.Join(rawValue: raw) == nil ? "No join named \(raw)." : nil
        case .setSceneBackground(let hex):
            return NewDocumentSpec.color(hex: hex) == nil ? "Use 6 hex digits, like FF3B30." : nil
        case .easingPreset, .easingHandle:
            if let reason = model.easingUnavailableReason { return reason }
            return model.selectedEasingSegment == nil ? "Select a keyframe span to ease it." : nil
        }
    }
}
