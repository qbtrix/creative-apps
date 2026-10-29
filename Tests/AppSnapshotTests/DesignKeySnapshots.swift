// DesignKeySnapshots.swift: Design's key buttons and Animate menu (one-document OD-13). The inspector with one layer
// selected in the button's three states: idle (`cards`, no keys), animated (`animated(1)` at frame 60, between its
// keys) and keyedHere (`animated(1)` at frame 0, on a key). The Animate menu's items in two columns: a still document
// (Play/Pause, Stop and Remove Key off, saying "Set a key first.") and a keyed one with a layer selected. Light and
// dark: design-key-{idle,animated,here}-{light,dark}.png and design-animate-menu-{light,dark}.png. `press` (render
// budget) opens `animated(1)` at frame 60 with node-2 selected, clicks the X row's diamond and counts window and
// editor bodies; the key lands at 60 with the value shown there, so the canvas paints the same page. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing
@testable import DesignApp

@MainActor
@Suite struct DesignKeySnapshots {
    /// `doc` with node-2 selected and the playhead at `frame`.
    static func selected(_ doc: DesignWorkspace, at frame: Int?) -> DesignWorkspace {
        var doc = doc
        doc.useServices(.live)
        doc.selectItem("node-2")
        doc.setPlayhead(frame)
        return doc
    }

    @Test func keyStates() throws {
        let states: [(String, DesignWorkspace, SuiteKernel.KeyState)] = [
            ("idle", Self.selected(DesignFixtures.cards, at: nil), .notAnimated),
            ("animated", Self.selected(DesignFixtures.animated(1), at: 60), .animated),
            ("here", Self.selected(DesignFixtures.animated(1), at: 0), .keyedHere),
        ]
        for (name, doc, state) in states {
            #expect(doc.keyState("node-2", .x) == state, "\(name)")
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(KeyPanel(model: doc), name: "design-key-\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
            }
        }
    }

    @Test func animateMenu() throws {
        let menus = [Self.selected(DesignFixtures.cards, at: nil), Self.selected(DesignFixtures.animated(1), at: 60)]
            .map { DesignMenu(model: $0, perform: { _ in }) }
        let why = { (menu: DesignMenu, id: String) in DesignMenuState.spec(id).availability(menu.state()).why }
        for id in ["animate.play-pause", "animate.stop", "keyframe.remove"] {
            #expect(why(menus[0], id) == "Set a key first.", "\(id) on a still document")
            #expect(why(menus[1], id) == nil, "\(id) on a keyed document")
        }
        #expect(why(menus[0], "keyframe.set") == nil && why(menus[1], "keyframe.set") == nil)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(AnimateMenuStates(menus: menus), name: "design-animate-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignKeyTests {
        @Test(.timeLimit(.minutes(2))) func press() async throws {
            #if DEBUG
            let seed = DesignKeySnapshots.selected(DesignFixtures.animated(1), at: 60)
            let w = RenderBudgetWindow(DesignWindow(seed: seed, live: DesignLiveDrag()))
            defer { w.close() }
            try await w.settle(800)
            let bodies = { DesignWindow.bodyRuns + DesignEditor.bodyRuns }
            try await w.settle(untilStable: { bodies() })
            let diamond = try #require(await w.element(KeyframeButton.diamondID(DesignControlID.inspectorKey(.x))), "no X diamond")
            let shown = seed.shownPage
            let (window, editor) = (DesignWindow.bodyRuns, DesignEditor.bodyRuns)
            w.click(at: CGPoint(x: diamond.midX, y: diamond.midY))
            try await w.settle(400)
            let ranWindow = DesignWindow.bodyRuns - window, ranEditor = DesignEditor.bodyRuns - editor
            perform(try #require(DesignWindow.lastPerform))
            let after = try #require(DesignWindow.lastWorkspace)
            print("BUDGET design key press, X diamond on animated(1) at 60: window bodies \(ranWindow) | editor bodies \(ranEditor)")
            #expect(after.keyState("node-2", .x) == .keyedHere, "the click didn't set a key at 60")
            #expect(after.shownPage == shown, "the key changed what the canvas shows at 60")
            #expect(after.canUndo && after.isDirty)
            #expect(ranWindow <= 1, "one key press runs the window at most once: \(ranWindow)")
            #expect(ranEditor <= 1, "one key press runs the editor at most once: \(ranEditor)")
            #endif
        }

        /// A no-op `.pause` records the window's workspace in `lastWorkspace`.
        private func perform(_ perform: DesignPerform) { perform(.pause) }
    }
}

/// The inspector at the editor's panel width.
private struct KeyPanel: View {
    let model: DesignWorkspace
    var body: some View {
        DesignInspector(model: model, perform: { _ in })
            .frame(width: SuiteSize.editorPanelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}

/// The Animate menu's items in a column per document, since the menu bar does not render here.
private struct AnimateMenuStates: View {
    let menus: [DesignMenu]
    private let titles = ["Still document", "Keyed, a layer selected"]

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(menus.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    Text(titles[index]).font(SuiteFont.headline)
                    DesignAnimateMenu(menu: menus[index])
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif
