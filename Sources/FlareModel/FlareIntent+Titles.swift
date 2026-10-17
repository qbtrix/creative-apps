// FlareIntent+Titles.swift: DK-2b of draw-key-save (#347). The title a menu item or toolbar action shows for
// each FlareIntent, in the words of docs/blueprints/flare.md section 3.4 (the menu bar and its context menus).
// Cases with no menu item get a short descriptive title. `toolbarTitle` gives the packet's shorter toolbar
// words (Open, Auto-key, Animate…) where they differ. Every case has a unique title. Linux-safe.
import FlareCore

extension FlareIntent {
    /// The menu title, section 3.4's words. Undo and Redo get their step name appended by the menu.
    public var title: String {
        switch self {
        case .file(let intent): intent.title
        case .edit(let intent): intent.title
        case .stage(let intent): intent.title
        case .tools(let intent): intent.title
        case .view(let intent): intent.title
        case .inspector(let intent): intent.title
        case .timeline(let intent): intent.title
        case .layers(let intent): intent.title
        case .library(let intent): intent.title
        case .interactions(.toggleEditor): "Interactions"
        case .export(let intent): intent.title
        case .assist(.showPopover): "Animate with Assist…"
        }
    }

    /// The title on the window toolbar: the packet's list (New, Open, Save, Undo, Redo, Auto-key,
    /// Animate…, Export…); the menu title for every other case.
    public var toolbarTitle: String {
        switch self {
        case .file(.open): "Open"
        case .timeline(.toggleAutoKey): "Auto-key"
        case .assist(.showPopover): "Animate…"
        case .file, .edit, .stage, .tools, .view, .inspector, .timeline, .layers, .library, .interactions,
             .export: title
        }
    }
}

extension FlareIntent.File {
    var title: String {
        switch self {
        case .new: "New"
        case .create: "Create"
        case .open: "Open…"
        case .openRecent: "Open Recent"
        case .clearRecent: "Clear Menu"
        case .openSample: "Open Sample"
        case .save: "Save"
        case .saveAs: "Save As…"
        case .close: "Close"
        }
    }
}

extension FlareIntent.Edit {
    var title: String {
        switch self {
        case .undo: "Undo"
        case .redo: "Redo"
        case .cut: "Cut"
        case .copy: "Copy"
        case .paste: "Paste"
        case .duplicate: "Duplicate"
        case .delete: "Delete"
        case .selectAll: "Select All"
        case .deselect: "Deselect"
        case .bringForward: "Bring Forward"
        case .sendBackward: "Send Backward"
        }
    }
}

extension FlareIntent.Stage {
    var title: String {
        switch self {
        case .dragChanged: "Drag on Stage"
        case .endDrag: "End Drag"
        case .cancelDrag: "Cancel Drag"
        }
    }
}

extension FlareIntent.Tools {
    var title: String {
        switch self {
        case .choose(let tool):
            switch tool {
            case .select: "Select"
            case .directSelect: "Direct Select"
            case .pen: "Pen"
            case .rectangle: "Rectangle"
            case .ellipse: "Ellipse"
            }
        case .finishPath: "Finish Path"
        }
    }
}

extension FlareIntent.View {
    var title: String {
        switch self {
        case .zoomIn: "Zoom In"
        case .zoomOut: "Zoom Out"
        case .fit: "Fit"
        case .actualSize: "Actual Size"
        case .toggleOnion: "Onion Skin"
        case .toggleMotionPath: "Motion Path"
        case .toggleRulers: "Show Rulers"
        case .toggleGuides: "Show Guides"
        case .clearGuides: "Clear Guides"
        case .addGuide: "Add Guide"
        case .moveGuide: "Move Guide"
        case .endGuideDrag: "End Guide Drag"
        case .removeGuide: "Remove Guide"
        }
    }
}

extension FlareIntent.Inspector {
    var title: String {
        switch self {
        case .showTab: "Show Tab"
        case .scrub: "Scrub Value"
        case .endScrub: "End Scrub"
        case .toggleAnimated: "Animate Property"
        case .toggleKey: "Toggle Keyframe"
        case .setFill: "Fill"
        case .setStrokeColor: "Stroke Color"
        case .setStrokeWidth: "Stroke Width"
        case .setStrokeCap: "Stroke Cap"
        case .setStrokeJoin: "Stroke Join"
        case .setSceneSize: "Scene Size"
        case .setSceneBackground: "Scene Background"
        case .setSceneTiming: "Scene Timing"
        case .easingPreset: "Easing"
        case .easingHandle: "Move Easing Handle"
        case .endEasingHandle: "End Easing Handle"
        }
    }
}

extension FlareIntent.Timeline {
    var title: String {
        switch self {
        case .scrub: "Scrub"
        case .goToStart: "Go to Start"
        case .goToEnd: "Go to End"
        case .step(let frames): frames < 0 ? "Previous Frame" : "Next Frame"
        case .nextKeyframe: "Next Keyframe"
        case .previousKeyframe: "Previous Keyframe"
        case .togglePlay: "Play/Pause"
        case .setLoops: "Loop"
        case .toggleAutoKey: "Auto-Key"
        case .selectKey: "Select Keyframe"
        case .moveKeys: "Move Keyframes"
        case .endKeyDrag: "End Keyframe Drag"
        case .removeKeys: "Delete Keyframe"
        case .addKey: "Add Keyframe"
        case .removeKey: "Remove Keyframe"
        case .insertFrames: "Insert Frame"
        case .removeFrames: "Remove Frame"
        case .setLabel: "Add Label"
        }
    }
}

extension FlareIntent.Layers {
    var title: String {
        switch self {
        case .select: "Select Layer"
        case .toggle(_, let flag): flag == FlareLayerFlag.locked.rawValue ? "Lock Layer" : "Hide Layer"
        case .move: "Reorder"
        case .rename: "Rename Layer"
        case .addLayer: "Add Layer"
        case .addScene: "Add Scene"
        case .remove: "Delete Layer"
        case .duplicate: "Duplicate Layer"
        }
    }
}

extension FlareIntent.Export {
    /// Export… opens the sheet (File menu, toolbar); the rest are the sheet's own rows and buttons
    /// (docs/blueprints/flare/features/flare-export.md), so a format chip's title names its format.
    var title: String {
        switch self {
        case .showSheet: "Export…"
        case .setFormat(let format):
            switch format {
            case .svgFrame: "SVG frame"
            case .lottie: "Lottie"
            case .pngSequence: "PNG sequence"
            }
        case .setFrames: "Frames"
        case .setStep: "Step"
        case .setScale: "Scale"
        case .setTransparent: "Transparent background"
        case .start: "Export"
        case .cancel: "Cancel"
        case .dismiss: "Done"
        case .tryAgain: "Try Again"
        case .reveal: "Reveal in Finder"
        }
    }
}

extension FlareIntent.Library {
    var title: String {
        switch self {
        case .convertToSymbol: "Convert to Symbol"
        case .place: "Place"
        case .edit: "Edit Symbol"
        case .exitSymbol: "Exit Symbol"
        case .rename: "Rename Symbol"
        case .remove: "Delete Symbol"
        case .addSwatch: "Add Swatch"
        case .applySwatch: "Apply Swatch"
        case .removeSwatch: "Remove Swatch"
        }
    }
}
