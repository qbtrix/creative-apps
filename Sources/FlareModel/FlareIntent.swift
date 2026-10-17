// FlareIntent.swift: DK-2a of draw-key-save (#347). Everything a person can ask Flare's window to do, as one
// value: a top-level area and a nested case with plain-value payloads. Each case has a stable `identifier`,
// "flare.<area>.<case name>", that no payload changes, so a menu item, toolbar action or UI test can name it.
// The cases are the packet's contract slice in full (docs/blueprints/flare/features/draw-key-save.md);
// DK-2b adds the titles in FlareIntent+Titles.swift. Linux-safe.
import FlareCore

/// One thing a person can ask Flare's window to do.
public enum FlareIntent: Sendable, Equatable {
    case file(File), edit(Edit), stage(Stage), tools(Tools), view(View), inspector(Inspector),
         timeline(Timeline), layers(Layers), library(Library), interactions(Interactions),
         export(Export), assist(Assist)

    /// The part of the window an intent belongs to; its raw value is the identifier's middle part.
    public enum Area: String, CaseIterable, Sendable {
        case file, edit, stage, tools, view, inspector,
             timeline, layers, library, interactions, export, assist
    }

    public enum File: Sendable, Equatable {
        case new, create(preset: String?, width: Double, height: Double,
                         fps: Int, durationFrames: Int, backgroundHex: String), open, openRecent(path: String),
             clearRecent, openSample(name: String), save, saveAs, close
    }

    public enum Edit: Sendable, Equatable {
        case undo, redo, cut, copy, paste, duplicate, delete, selectAll, deselect, bringForward, sendBackward
    }

    public enum Stage: Sendable, Equatable {
        case dragChanged(start: Point, end: Point, shift: Bool, option: Bool, stageScale: Double),
             endDrag, cancelDrag
    }

    public enum Tools: Sendable, Equatable {
        case choose(FlareTool), finishPath
    }

    public enum View: Sendable, Equatable {
        case zoomIn, zoomOut, fit, actualSize, toggleOnion, toggleMotionPath,
             toggleRulers, toggleGuides, clearGuides, addGuide(horizontal: Bool, at: Double),
             moveGuide(index: Int, to: Double, dragStart: Double), endGuideDrag, removeGuide(index: Int)
    }

    public enum Inspector: Sendable, Equatable {
        case showTab(String), scrub(property: String, value: Double, dragStart: Double), endScrub,
             toggleAnimated(String), toggleKey(String), setFill(hex: String), setStrokeColor(hex: String),
             setStrokeWidth(Double), setStrokeCap(String), setStrokeJoin(String),
             setSceneSize(width: Double, height: Double), setSceneBackground(hex: String),
             setSceneTiming(fps: Int, durationFrames: Int), easingPreset(String),
             easingHandle(index: Int, x: Double, y: Double), endEasingHandle
    }

    public enum Timeline: Sendable, Equatable {
        case scrub(frame: Int), goToStart, goToEnd, step(Int), nextKeyframe, previousKeyframe, togglePlay,
             setLoops(Bool), toggleAutoKey, selectKey(layerID: String, property: String?, frame: Int, extending: Bool),
             moveKeys(by: Int, dragStart: Int), endKeyDrag, removeKeys, addKey, removeKey,
             insertFrames(Int), removeFrames(Int), setLabel(String?)
    }

    public enum Layers: Sendable, Equatable {
        case select(id: String), toggle(id: String, flag: String), move(section: String, from: Int, to: Int),
             rename(id: String, name: String), addLayer, addScene, remove(id: String), duplicate(id: String)
    }

    public enum Library: Sendable, Equatable {
        case convertToSymbol(name: String), place(id: String), edit(id: String), exitSymbol,
             rename(id: String, name: String), remove(id: String), addSwatch, applySwatch(Int), removeSwatch(Int)
    }

    /// The interactions editor's own controls come later (tier 3).
    public enum Interactions: Sendable, Equatable { case toggleEditor }
    /// The Export sheet (flare-export FX-1): its opener, its option rows and its actions. `setFormat` is one
    /// case whose three payloads are three chips, so its name carries the format.
    public enum Export: Sendable, Equatable {
        case showSheet, setFormat(ExportFormat), setFrames(from: Int, to: Int), setStep(Int), setScale(Double),
             setTransparent(Bool), start, cancel, dismiss, tryAgain, reveal
    }
    public enum Assist: Sendable, Equatable { case showPopover }

    /// The area this intent belongs to.
    public var area: Area {
        switch self {
        case .file: .file
        case .edit: .edit
        case .stage: .stage
        case .tools: .tools
        case .view: .view
        case .inspector: .inspector
        case .timeline: .timeline
        case .layers: .layers
        case .library: .library
        case .interactions: .interactions
        case .export: .export
        case .assist: .assist
        }
    }

    /// "flare.<area>.<case name>": unique per case; payloads don't change it.
    public var identifier: String { "flare.\(area.rawValue).\(caseName)" }

    var caseName: String {
        switch self {
        case .file(let intent): intent.name
        case .edit(let intent): intent.name
        case .stage(let intent): intent.name
        case .tools(let intent): intent.name
        case .view(let intent): intent.name
        case .inspector(let intent): intent.name
        case .timeline(let intent): intent.name
        case .layers(let intent): intent.name
        case .library(let intent): intent.name
        case .interactions: "toggleEditor"
        case .export(let intent): intent.name
        case .assist: "showPopover"
        }
    }

    /// One representative value of every case, in contract order, so tests can enumerate them all.
    /// A new case must be added here too; FlareIntentTests counts them.
    public static let examples: [FlareIntent] = [
        .file(.new), .file(.create(preset: nil, width: 1920, height: 1080, fps: 24, durationFrames: 48,
                                   backgroundHex: "#FFFFFF")),
        .file(.open), .file(.openRecent(path: "")), .file(.clearRecent), .file(.openSample(name: "")),
        .file(.save), .file(.saveAs), .file(.close),
        .edit(.undo), .edit(.redo), .edit(.cut), .edit(.copy), .edit(.paste), .edit(.duplicate), .edit(.delete),
        .edit(.selectAll), .edit(.deselect), .edit(.bringForward), .edit(.sendBackward),
        .stage(.dragChanged(start: Point(x: 0, y: 0), end: Point(x: 0, y: 0), shift: false, option: false,
                            stageScale: 1)),
        .stage(.endDrag), .stage(.cancelDrag),
        .tools(.choose(.select)), .tools(.finishPath),
        .view(.zoomIn), .view(.zoomOut), .view(.fit), .view(.actualSize), .view(.toggleOnion),
        .view(.toggleMotionPath), .view(.toggleRulers), .view(.toggleGuides), .view(.clearGuides),
        .view(.addGuide(horizontal: true, at: 0)), .view(.moveGuide(index: 0, to: 0, dragStart: 0)),
        .view(.endGuideDrag), .view(.removeGuide(index: 0)),
        .inspector(.showTab("")), .inspector(.scrub(property: "", value: 0, dragStart: 0)), .inspector(.endScrub),
        .inspector(.toggleAnimated("")), .inspector(.toggleKey("")), .inspector(.setFill(hex: "")),
        .inspector(.setStrokeColor(hex: "")), .inspector(.setStrokeWidth(1)), .inspector(.setStrokeCap("")),
        .inspector(.setStrokeJoin("")), .inspector(.setSceneSize(width: 1, height: 1)),
        .inspector(.setSceneBackground(hex: "")), .inspector(.setSceneTiming(fps: 24, durationFrames: 48)),
        .inspector(.easingPreset("")), .inspector(.easingHandle(index: 0, x: 0, y: 0)),
        .inspector(.endEasingHandle),
        .timeline(.scrub(frame: 0)), .timeline(.goToStart), .timeline(.goToEnd), .timeline(.step(1)),
        .timeline(.nextKeyframe), .timeline(.previousKeyframe), .timeline(.togglePlay), .timeline(.setLoops(true)),
        .timeline(.toggleAutoKey), .timeline(.selectKey(layerID: "", property: nil, frame: 0, extending: false)),
        .timeline(.moveKeys(by: 0, dragStart: 0)), .timeline(.endKeyDrag), .timeline(.removeKeys),
        .timeline(.addKey), .timeline(.removeKey), .timeline(.insertFrames(1)), .timeline(.removeFrames(1)),
        .timeline(.setLabel(nil)),
        .layers(.select(id: "")), .layers(.toggle(id: "", flag: "")), .layers(.move(section: "", from: 0, to: 0)),
        .layers(.rename(id: "", name: "")), .layers(.addLayer), .layers(.addScene), .layers(.remove(id: "")),
        .layers(.duplicate(id: "")),
        .library(.convertToSymbol(name: "")), .library(.place(id: "")), .library(.edit(id: "")),
        .library(.exitSymbol), .library(.rename(id: "", name: "")), .library(.remove(id: "")),
        .library(.addSwatch), .library(.applySwatch(0)), .library(.removeSwatch(0)),
        .interactions(.toggleEditor),
        .export(.showSheet), .export(.setFormat(.svgFrame)), .export(.setFrames(from: 0, to: 47)),
        .export(.setStep(1)), .export(.setScale(1)), .export(.setTransparent(false)), .export(.start),
        .export(.cancel), .export(.dismiss), .export(.tryAgain), .export(.reveal),
        .assist(.showPopover),
    ]
}

extension FlareIntent.File {
    var name: String {
        switch self {
        case .new: "new"
        case .create: "create"
        case .open: "open"
        case .openRecent: "openRecent"
        case .clearRecent: "clearRecent"
        case .openSample: "openSample"
        case .save: "save"
        case .saveAs: "saveAs"
        case .close: "close"
        }
    }
}

extension FlareIntent.Edit {
    var name: String {
        switch self {
        case .undo: "undo"
        case .redo: "redo"
        case .cut: "cut"
        case .copy: "copy"
        case .paste: "paste"
        case .duplicate: "duplicate"
        case .delete: "delete"
        case .selectAll: "selectAll"
        case .deselect: "deselect"
        case .bringForward: "bringForward"
        case .sendBackward: "sendBackward"
        }
    }
}

extension FlareIntent.Stage {
    var name: String {
        switch self {
        case .dragChanged: "dragChanged"
        case .endDrag: "endDrag"
        case .cancelDrag: "cancelDrag"
        }
    }
}

extension FlareIntent.Tools {
    var name: String {
        switch self {
        case .choose: "choose"
        case .finishPath: "finishPath"
        }
    }
}

extension FlareIntent.View {
    var name: String {
        switch self {
        case .zoomIn: "zoomIn"
        case .zoomOut: "zoomOut"
        case .fit: "fit"
        case .actualSize: "actualSize"
        case .toggleOnion: "toggleOnion"
        case .toggleMotionPath: "toggleMotionPath"
        case .toggleRulers: "toggleRulers"
        case .toggleGuides: "toggleGuides"
        case .clearGuides: "clearGuides"
        case .addGuide: "addGuide"
        case .moveGuide: "moveGuide"
        case .endGuideDrag: "endGuideDrag"
        case .removeGuide: "removeGuide"
        }
    }
}

extension FlareIntent.Inspector {
    var name: String {
        switch self {
        case .showTab: "showTab"
        case .scrub: "scrub"
        case .endScrub: "endScrub"
        case .toggleAnimated: "toggleAnimated"
        case .toggleKey: "toggleKey"
        case .setFill: "setFill"
        case .setStrokeColor: "setStrokeColor"
        case .setStrokeWidth: "setStrokeWidth"
        case .setStrokeCap: "setStrokeCap"
        case .setStrokeJoin: "setStrokeJoin"
        case .setSceneSize: "setSceneSize"
        case .setSceneBackground: "setSceneBackground"
        case .setSceneTiming: "setSceneTiming"
        case .easingPreset: "easingPreset"
        case .easingHandle: "easingHandle"
        case .endEasingHandle: "endEasingHandle"
        }
    }
}

extension FlareIntent.Timeline {
    var name: String {
        switch self {
        case .scrub: "scrub"
        case .goToStart: "goToStart"
        case .goToEnd: "goToEnd"
        case .step: "step"
        case .nextKeyframe: "nextKeyframe"
        case .previousKeyframe: "previousKeyframe"
        case .togglePlay: "togglePlay"
        case .setLoops: "setLoops"
        case .toggleAutoKey: "toggleAutoKey"
        case .selectKey: "selectKey"
        case .moveKeys: "moveKeys"
        case .endKeyDrag: "endKeyDrag"
        case .removeKeys: "removeKeys"
        case .addKey: "addKey"
        case .removeKey: "removeKey"
        case .insertFrames: "insertFrames"
        case .removeFrames: "removeFrames"
        case .setLabel: "setLabel"
        }
    }
}

extension FlareIntent.Layers {
    var name: String {
        switch self {
        case .select: "select"
        case .toggle: "toggle"
        case .move: "move"
        case .rename: "rename"
        case .addLayer: "addLayer"
        case .addScene: "addScene"
        case .remove: "remove"
        case .duplicate: "duplicate"
        }
    }
}

extension FlareIntent.Export {
    /// The case name, except the format chips: "format.<rawValue>", one identifier per chip.
    var name: String {
        switch self {
        case .showSheet: "showSheet"
        case .setFormat(let format): "format.\(format.rawValue)"
        case .setFrames: "setFrames"
        case .setStep: "setStep"
        case .setScale: "setScale"
        case .setTransparent: "setTransparent"
        case .start: "start"
        case .cancel: "cancel"
        case .dismiss: "dismiss"
        case .tryAgain: "tryAgain"
        case .reveal: "reveal"
        }
    }
}

extension FlareIntent.Library {
    var name: String {
        switch self {
        case .convertToSymbol: "convertToSymbol"
        case .place: "place"
        case .edit: "edit"
        case .exitSymbol: "exitSymbol"
        case .rename: "rename"
        case .remove: "remove"
        case .addSwatch: "addSwatch"
        case .applySwatch: "applySwatch"
        case .removeSwatch: "removeSwatch"
        }
    }
}
