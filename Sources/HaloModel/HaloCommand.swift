// HaloCommand.swift: every command Halo's v1 window can send, each in one of
// nine areas, with its menu title; whether it can act now is
// `HaloProject.unavailableHelp(for:)`, which asks the area's file in
// `Availability/`. The list is complete: a feature turns its area's commands
// on by replacing its area file, never by adding a case here. Also the
// dialogs an area's route asks the window to show (`HaloWindowRequest`).
// Linux-safe: no UI imports.
import CoreRaster

/// The nine areas, one availability file each.
public enum HaloCommandArea: Sendable, CaseIterable {
    case composition, playback, keys, layers, history, files, easing, render, text
}

/// One thing a menu, a row, a drag or the transport asks the window to do.
public enum HaloCommand: Hashable, Sendable, CaseIterable {
    // composition
    case newComposition, duplicateComposition, deleteComposition
    case selectComposition(String), renameComposition(String, String)
    // layers
    case newLayer(HaloLayerKind)
    case duplicateLayer, beginRenameLayer, deleteLayer, bringLayerForward, sendLayerBackward
    case renameLayer(String, String), moveLayer(String, to: Int), selectLayer(String?)
    // playback
    case playPause, toggleLoop, nextFrame, previousFrame, goToStart, goToEnd, setInPoint, setOutPoint
    case scrub(Int), tick(Double)
    // keys
    case setProperty(HaloProperty, Double), setPropertyText(HaloProperty, String), endPropertyScrub
    case toggleAnimation(HaloProperty), toggleKey(HaloProperty), setParent(String?), setBlendMode(BlendMode)
    case beginViewerDrag(x: Double, y: Double), moveViewerDrag(x: Double, y: Double), endViewerDrag, cancelViewerDrag
    // history
    case undo, redo
    // files
    case save, saveAs, open, openRecent(String)
    // easing
    case setEasing(HaloEasingPreset), selectKey(HaloKeyRef, extending: Bool)
    case selectLaneKeys(layerID: String, frame: Int, extending: Bool), clearKeySelection
    case setCustomEasing(HaloEasing), moveEasingHandle(index: Int, x: Double, y: Double), endEasingDrag
    // render
    case renderFrame, openRenderSheet, startRender(HaloRenderSettings), cancelRender, closeRenderSheet
    // text
    case setText(String), setFontSize(Double), endTextSizeScrub, setLayerColor(HaloLayerColor)

    /// Every case once, payload cases with one sample payload (ids from the
    /// `keyed` fixture), so a test can walk them all.
    public static let allCases: [HaloCommand] = [
        .newComposition, .duplicateComposition, .deleteComposition, .selectComposition("comp-1"),
        .renameComposition("comp-1", "Intro"),
        .newLayer(.solid), .duplicateLayer, .beginRenameLayer, .renameLayer("comp-1-layer-2", "Ball 2"), .deleteLayer,
        .bringLayerForward, .sendLayerBackward, .moveLayer("comp-1-layer-2", to: 1), .selectLayer("comp-1-layer-2"),
        .playPause, .toggleLoop, .nextFrame, .previousFrame, .goToStart, .goToEnd, .setInPoint, .setOutPoint,
        .scrub(12), .tick(0.5),
        .setProperty(.x, 100), .setPropertyText(.x, "100"), .endPropertyScrub, .toggleAnimation(.x), .toggleKey(.x),
        .setParent("comp-1-layer-1"), .setBlendMode(.multiply), .beginViewerDrag(x: 10, y: 10),
        .moveViewerDrag(x: 20, y: 20), .endViewerDrag, .cancelViewerDrag,
        .undo, .redo,
        .save, .saveAs, .open, .openRecent("/tmp/Bounce.halo"),
        .setEasing(.easeInOut), .selectKey(HaloKeyRef(layerID: "comp-1-layer-2", property: .x, frame: 0), extending: false),
        .selectLaneKeys(layerID: "comp-1-layer-2", frame: 0, extending: false), .clearKeySelection,
        .setCustomEasing(HaloEasingPreset.easeIn.easing), .moveEasingHandle(index: 0, x: 0.3, y: 0), .endEasingDrag,
        .renderFrame, .openRenderSheet, .startRender(HaloRenderSettings(format: .pngSequence)), .cancelRender,
        .closeRenderSheet,
        .setText("Hello"), .setFontSize(48), .endTextSizeScrub, .setLayerColor(HaloLayerColor(red: 1, green: 0, blue: 0)),
    ]

    /// The area whose availability file answers for this command.
    public var area: HaloCommandArea {
        switch self {
        case .newComposition, .duplicateComposition, .deleteComposition, .selectComposition, .renameComposition:
            .composition
        case .newLayer, .duplicateLayer, .beginRenameLayer, .renameLayer, .deleteLayer, .bringLayerForward,
            .sendLayerBackward, .moveLayer, .selectLayer:
            .layers
        case .playPause, .toggleLoop, .nextFrame, .previousFrame, .goToStart, .goToEnd, .setInPoint, .setOutPoint,
            .scrub, .tick:
            .playback
        case .setProperty, .setPropertyText, .endPropertyScrub, .toggleAnimation, .toggleKey, .setParent,
            .setBlendMode, .beginViewerDrag, .moveViewerDrag, .endViewerDrag, .cancelViewerDrag:
            .keys
        case .undo, .redo: .history
        case .save, .saveAs, .open, .openRecent: .files
        case .setEasing, .selectKey, .selectLaneKeys, .clearKeySelection, .setCustomEasing, .moveEasingHandle,
            .endEasingDrag:
            .easing
        case .renderFrame, .openRenderSheet, .startRender, .cancelRender, .closeRenderSheet: .render
        case .setText, .setFontSize, .endTextSizeScrub, .setLayerColor: .text
        }
    }

    /// The menu or help title; Undo and Redo read their step through
    /// `HaloProject.title(for:)`.
    public var title: String {
        switch self {
        case .newComposition: "New Composition…"
        case .duplicateComposition, .duplicateLayer: "Duplicate"
        case .deleteComposition, .deleteLayer: "Delete"
        case .selectComposition: "Select Composition"
        case .renameComposition: "Rename Composition"
        case .newLayer(let kind): kind.title
        case .beginRenameLayer: "Rename…"
        case .renameLayer: "Rename Layer"
        case .bringLayerForward: "Bring Forward"
        case .sendLayerBackward: "Send Backward"
        case .moveLayer: "Move Layer"
        case .selectLayer: "Select Layer"
        case .playPause: "Play/Pause"
        case .toggleLoop: "Loop"
        case .nextFrame: "Next Frame"
        case .previousFrame: "Previous Frame"
        case .goToStart: "Go to Start"
        case .goToEnd: "Go to End"
        case .setInPoint: "Set In Point"
        case .setOutPoint: "Set Out Point"
        case .scrub: "Move Playhead"
        case .tick: "Play Frame"
        case .setProperty(let p, _), .setPropertyText(let p, _): "Change \(p.title)"
        case .endPropertyScrub: "End Change"
        case .toggleAnimation(let p): "Animate \(p.title)"
        case .toggleKey(let p): "Key \(p.title)"
        case .setParent: "Parent"
        case .setBlendMode: "Blend"
        case .beginViewerDrag, .moveViewerDrag, .endViewerDrag: "Drag Layer"
        case .cancelViewerDrag: "Cancel Drag"
        case .undo: "Undo"
        case .redo: "Redo"
        case .save: "Save"
        case .saveAs: "Save As…"
        case .open: "Open…"
        case .openRecent(let path): path.split(separator: "/").last.map(String.init) ?? path
        case .setEasing(let preset): preset.title
        case .selectKey: "Select Key"
        case .selectLaneKeys: "Select Keys"
        case .clearKeySelection: "Clear Key Selection"
        case .setCustomEasing: "Custom Easing"
        case .moveEasingHandle: "Move Easing Handle"
        case .endEasingDrag: "End Easing Change"
        case .renderFrame: "Render Frame"
        case .openRenderSheet: "Render…"
        case .startRender: "Render"
        case .cancelRender: "Cancel Render"
        case .closeRenderSheet: "Close"
        case .setText: "Edit Text"
        case .setFontSize: "Text Size"
        case .endTextSizeScrub: "End Text Size Change"
        case .setLayerColor: "Color"
        }
    }
}

/// A dialog an area's route asks the window to show; the area's scene hook
/// presents it and sets it back to nil.
public enum HaloWindowRequest: Hashable, Sendable {
    /// Rename Layer… for this layer id.
    case renameLayer(String)
    case saveAs
    case open
    /// The unsaved-changes question, then this command if the user goes on.
    case confirmUnsaved(then: HaloCommand)
}

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not, for the control's
    /// help. Each area answers in its own `Availability/` file.
    public func unavailableHelp(for command: HaloCommand) -> String? {
        switch command.area {
        case .composition: compositionHelp(command)
        case .playback: playbackHelp(command)
        case .keys: keysHelp(command)
        case .layers: layersHelp(command)
        case .history: historyHelp(command)
        case .files: filesHelp(command)
        case .easing: easingHelp(command)
        case .render: renderHelp(command)
        case .text: textHelp(command)
        }
    }

    /// The command's title; Undo and Redo name their step ("Undo New Layer").
    public func title(for command: HaloCommand) -> String {
        switch command {
        case .undo: history.undoTitle ?? command.title
        case .redo: history.redoTitle ?? command.title
        default: command.title
        }
    }
}
