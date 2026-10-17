// FlareIntentTitleTests.swift: DK-2b of draw-key-save (#347). Every menu item of docs/blueprints/flare.md
// section 3.4 and every toolbar action of the packet maps to exactly one FlareIntent with that title.
// The Flare menu (About, Hide, Quit), Window's system items and Help are the system's and have no intent.
import FlareCore
import FlareModel
import Testing

struct FlareIntentTitleTests {
    struct Item: Sendable {
        let menu: String, title: String, intent: FlareIntent
        init(_ menu: String, _ title: String, _ intent: FlareIntent) {
            self.menu = menu; self.title = title; self.intent = intent
        }
    }

    /// Section 3.4, menu by menu, in its order.
    static let menuBar: [Item] = [
        Item("File", "New", .file(.new)), Item("File", "Open…", .file(.open)),
        Item("File", "Open Recent", .file(.openRecent(path: "/tmp/a.flare"))),
        Item("File", "Open Sample", .file(.openSample(name: "bounce"))), Item("File", "Save", .file(.save)),
        Item("File", "Save As…", .file(.saveAs)), Item("File", "Export…", .export(.showSheet)),
        Item("File", "Close", .file(.close)),
        Item("Edit", "Undo", .edit(.undo)), Item("Edit", "Redo", .edit(.redo)), Item("Edit", "Cut", .edit(.cut)),
        Item("Edit", "Copy", .edit(.copy)), Item("Edit", "Paste", .edit(.paste)),
        Item("Edit", "Duplicate", .edit(.duplicate)), Item("Edit", "Delete", .edit(.delete)),
        Item("Edit", "Select All", .edit(.selectAll)), Item("Edit", "Deselect", .edit(.deselect)),
        Item("View", "Zoom In", .view(.zoomIn)), Item("View", "Zoom Out", .view(.zoomOut)),
        Item("View", "Fit", .view(.fit)), Item("View", "Actual Size", .view(.actualSize)),
        Item("View", "Onion Skin", .view(.toggleOnion)), Item("View", "Motion Path", .view(.toggleMotionPath)),
        Item("View", "Show Rulers", .view(.toggleRulers)), Item("View", "Show Guides", .view(.toggleGuides)),
        Item("View", "Clear Guides", .view(.clearGuides)),
        Item("Object", "Convert to Symbol", .library(.convertToSymbol(name: "Walk cycle"))),
        Item("Object", "Edit Symbol", .library(.edit(id: "s1"))), Item("Object", "Exit Symbol", .library(.exitSymbol)),
        Item("Object", "Bring Forward", .edit(.bringForward)), Item("Object", "Send Backward", .edit(.sendBackward)),
        Item("Animate", "Play/Pause", .timeline(.togglePlay)), Item("Animate", "Loop", .timeline(.setLoops(true))),
        Item("Animate", "Next Frame", .timeline(.step(1))), Item("Animate", "Previous Frame", .timeline(.step(-1))),
        Item("Animate", "Next Keyframe", .timeline(.nextKeyframe)),
        Item("Animate", "Previous Keyframe", .timeline(.previousKeyframe)),
        Item("Animate", "Go to Start", .timeline(.goToStart)), Item("Animate", "Go to End", .timeline(.goToEnd)),
        Item("Animate", "Add Keyframe", .timeline(.addKey)), Item("Animate", "Remove Keyframe", .timeline(.removeKey)),
        Item("Animate", "Auto-Key", .timeline(.toggleAutoKey)), Item("Animate", "Insert Frame", .timeline(.insertFrames(1))),
        Item("Animate", "Remove Frame", .timeline(.removeFrames(1))), Item("Animate", "Add Label", .timeline(.setLabel("a"))),
        Item("Animate", "Easing", .inspector(.easingPreset("Ease In"))),
        Item("Animate", "Animate with Assist…", .assist(.showPopover)),
        Item("Window", "Interactions", .interactions(.toggleEditor)),
    ]

    /// The packet's toolbar list, in its order.
    static let toolbar: [(title: String, intent: FlareIntent)] = [
        ("New", .file(.new)), ("Open", .file(.open)), ("Save", .file(.save)), ("Undo", .edit(.undo)),
        ("Redo", .edit(.redo)), ("Auto-key", .timeline(.toggleAutoKey)), ("Animate…", .assist(.showPopover)),
        ("Export…", .export(.showSheet)),
    ]

    /// Every case once, plus the second direction of `step`, which titles two menu items, and the two
    /// export formats the examples don't carry, which title two more chips.
    static let everyValue: [FlareIntent] = FlareIntent.examples
        + [.timeline(.step(-1)), .export(.setFormat(.lottie)), .export(.setFormat(.pngSequence))]

    @Test func everyMenuItemHasItsSectionThreeFourTitle() {
        #expect(Self.menuBar.count == 48)
        for item in Self.menuBar {
            #expect(item.intent.title == item.title, "\(item.menu) > \(item.title)")
            let matches = Self.everyValue.filter { $0.title == item.title }
            #expect(matches.count == 1, "\(item.title) is the title of \(matches.count) intents")
            #expect(matches.first?.identifier == item.intent.identifier, "\(item.title)")
        }
    }

    @Test func noTwoItemsInOneMenuShareATitle() {
        for menu in Set(Self.menuBar.map(\.menu)) {
            let titles = Self.menuBar.filter { $0.menu == menu }.map(\.title)
            #expect(Set(titles).count == titles.count, "\(menu)")
        }
    }

    @Test func everyToolbarActionHasItsTitle() {
        #expect(Self.toolbar.map(\.title) == ["New", "Open", "Save", "Undo", "Redo", "Auto-key", "Animate…", "Export…"])
        for action in Self.toolbar {
            #expect(action.intent.toolbarTitle == action.title, "\(action.title)")
            let matches = Self.everyValue.filter { $0.toolbarTitle == action.title }
            #expect(matches.count == 1, "\(action.title) is the toolbar title of \(matches.count) intents")
        }
    }

    @Test func theToolbarTitleIsTheMenuTitleOutsideTheThreeShortForms() {
        #expect(FlareIntent.file(.open).title == "Open…")
        #expect(FlareIntent.timeline(.toggleAutoKey).title == "Auto-Key")
        #expect(FlareIntent.assist(.showPopover).title == "Animate with Assist…")
        let differing = Self.everyValue.filter { $0.toolbarTitle != $0.title }.map(\.identifier)
        #expect(differing == ["flare.file.open", "flare.timeline.toggleAutoKey", "flare.assist.showPopover"])
    }

    @Test func everyCaseHasAUniqueNonEmptyTitle() {
        let titles = Self.everyValue.map(\.title)
        #expect(!titles.contains(""))
        #expect(Set(titles).count == titles.count)
    }

    @Test func payloadsKeepTheTitleExceptStepDirectionToolLayerFlagAndExportFormat() {
        #expect(FlareIntent.timeline(.step(5)).title == "Next Frame")
        #expect(FlareIntent.export(.setFrames(from: 0, to: 9)).title == FlareIntent.export(.setFrames(from: 3, to: 4)).title)
        #expect(FlareIntent.export(.setStep(1)).title == FlareIntent.export(.setStep(2)).title)
        #expect(FlareIntent.export(.setScale(1)).title == FlareIntent.export(.setScale(2)).title)
        #expect(FlareIntent.export(.setTransparent(true)).title == FlareIntent.export(.setTransparent(false)).title)
        // The format chips are three rows, so the payload names each (flare-export FX-1).
        #expect(FlareIntent.export(.setFormat(.svgFrame)).title == "SVG frame")
        #expect(FlareIntent.export(.setFormat(.lottie)).title == "Lottie")
        #expect(FlareIntent.export(.setFormat(.pngSequence)).title == "PNG sequence")
        let formats = ExportFormat.allCases.map { FlareIntent.export(.setFormat($0)).title }
        #expect(Set(formats).count == ExportFormat.allCases.count)
        #expect(FlareIntent.timeline(.step(-5)).title == "Previous Frame")
        #expect(FlareIntent.timeline(.setLoops(false)).title == "Loop")
        #expect(FlareIntent.file(.openSample(name: "button")).title == "Open Sample")
        #expect(FlareIntent.tools(.choose(.pen)).title == "Pen")
        #expect(FlareIntent.tools(.choose(.directSelect)).title == "Direct Select")
        #expect(FlareIntent.layers(.toggle(id: "a", flag: FlareLayerFlag.locked.rawValue)).title == "Lock Layer")
        #expect(FlareIntent.layers(.toggle(id: "a", flag: FlareLayerFlag.visible.rawValue)).title == "Hide Layer")
        let tools = FlareTool.allCases.map { FlareIntent.tools(.choose($0)).title }
        #expect(Set(tools).count == FlareTool.allCases.count)
    }
}
