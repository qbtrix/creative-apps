// RenderBudgetTextStyleTests.swift (text-style TS-3, TS-4): the shared text style rows in the apps. The render budget
// (Tests/render-budgets.md): a Line Height drag of 120 samples on SuiteUI's TextStyleRows, in a real 1280 x 820
// window whose page owns the style and applies each `.lineHeight` intent through TextStyleRules, runs at most 3
// window bodies (target 0: only the page and the rows redraw), and sends at least one intent. Then the rows where a
// person reaches them: Design's text inspector on `cards` with Title (node-5) selected, and Halo's TEXT section on
// `empty` with a "Hello" text layer, each listing every `suite.text.*` control, disabled with "Text styles
// aren't connected in this window yet." until TS-8 and TS-10 route them, written as design-inspector-text-style-rows-{light,dark}.png and
// halo-text-style-rows-{light,dark}.png. Design shows no rows for a layer that isn't text. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import HaloModel
import SuiteKernel
import SuiteModel
import SwiftUI
import Testing

@testable import DesignApp
@testable import HaloApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetTextStyleTests {
        static let samples = 120

        @Test(.timeLimit(.minutes(2))) func lineHeightDragInThreeBodies() async throws {
            let w = RenderBudgetWindow(TextStyleBudgetWindow())
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return TextStyleBudgetWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            _ = try #require(await w.element("suite.text.line-height"), "the rows show no Line Height (suite.text.line-height)")
            let before = TextStyleBudgetPage.intents
            let step = try await w.measure("text style Line Height drag, \(Self.samples) steps", bodies: bodies) {
                let found = try await w.adjust("suite.text.line-height", steps: Self.samples)
                #expect(found, "Line Height can't be adjusted")
            }
            let sent = TextStyleBudgetPage.intents - before
            #expect(sent > 0 && sent <= Self.samples, "\(Self.samples) Line Height steps sent \(sent) intents")
            #expect(TextStyleBudgetPage.lineHeight > TextStyle.standard.paragraph.lineHeight, "the drag moved Line Height")
            expectBodies(step, atMost: 3, target: 0)
        }
    }
}

/// The counted window: a header over the page, which owns the style.
private struct TextStyleBudgetWindow: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Inspector").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText)
            TextStyleBudgetPage()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// TextStyleRows on the standard style over FakeText's families; each Line Height intent applied and counted.
private struct TextStyleBudgetPage: View {
    // view-static: main-actor
    static var intents = 0
    // view-static: main-actor
    static var lineHeight = TextStyle.standard.paragraph.lineHeight
    @State private var style = TextStyle.standard

    var body: some View {
        TextStyleRows(style: style, families: FakeText().families(), help: nil) { intent in
            guard case .lineHeight(let value, _) = intent else { return }
            Self.intents += 1
            style = TextStyleRules.setting(style, .lineHeight, to: value)
            Self.lineHeight = style.paragraph.lineHeight
        }
        .frame(width: SuiteSize.inspectorWidth.ideal)
        .background(SuiteColor.panel)
    }
}

@MainActor
@Suite struct TextStyleRowsInAppsSnapshots {
    static let help = "Text styles aren't connected in this window yet."

    /// `cards` on `.live` with `id` selected.
    private func cards(_ id: String) -> DesignWorkspace {
        var model = DesignWorkspace()
        model.useServices(.live)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectItem(id)
        return model
    }

    /// `empty` on `.fake` with a new text layer reading "Hello" at 96.
    private func hello() throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
        project.newLayer(.text)
        project.setText("Hello")
        project.setFontSize(96)
        project.endTextSizeScrub()
        return project
    }

    /// The `suite.text.*` controls `view` lists, sorted by id.
    private func textControls(_ view: some View) throws -> [ControlEntry] {
        let store = SuiteControlStore()
        _ = try #require(render(view.environment(\.suiteControlStore, store), scheme: .light))
        return store.inventory.document().controls.filter { $0.id.hasPrefix("suite.text.") }.sorted { $0.id < $1.id }
    }

    /// Every row's control is listed, disabled with the not-connected reason.
    private func expectRows(_ controls: [ControlEntry]) {
        let ids = Set(controls.map(\.id))
        for id in TextStyleRows.controlIDs + ["leading", "center", "trailing", "justified"].map({ "suite.text.alignment.\($0)" }) {
            #expect(ids.contains(id), "no \(id)")
        }
        for control in controls {
            #expect(!control.enabled && control.reason == Self.help, "\(control.id): \(control.enabled) \(control.reason ?? "nil")")
        }
    }

    @Test func designTitleShowsTheRows() throws {
        let model = cards("node-5")
        #expect(DesignInspectorText.textStylesHelp == Self.help)
        let style = try #require(DesignInspectorText(model: model, perform: { _ in }).textStyle)
        #expect(style.family == model.sharedTextStyle?.family && style.size == model.sharedTextStyle?.size)
        let view = DesignInspectorText(model: model, perform: { _ in })
        expectRows(try textControls(view))
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                view.padding(.vertical, SuiteSpacing.m)
                    .frame(width: SuiteSize.inspectorWidth.ideal)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(SuiteColor.panel),
                name: "design-inspector-text-style-rows-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func designShowsNoRowsForAShape() throws {
        let model = cards("node-2")
        #expect(DesignInspectorText(model: model, perform: { _ in }).textStyle == nil)
        #expect(try textControls(DesignInspectorText(model: model, perform: { _ in })).isEmpty)
    }

    @Test func designAlignmentMapsToTheKernel() {
        var style = DesignTextStyle.default
        let expected: [DesignTextAlignment: TextStyle.Alignment] = [.leading: .leading, .center: .center, .trailing: .trailing]
        for (design, kernel) in expected {
            style.alignment = design
            #expect(DesignInspectorText.kernelStyle(style).paragraph.alignment == kernel)
        }
    }

    @Test func haloTextShowsTheRows() throws {
        let project = try hello()
        let text = try #require(project.selectedText)
        #expect(HaloTextInspector.kernelStyle(text).size == 96 && project.textStyle?.size == 96)
        let unwired = try textControls(HaloTextInspector(model: project))
        #expect(!unwired.isEmpty && unwired.allSatisfy { !$0.enabled && $0.reason == HaloTextInspector.textStylesHelp })
        // TS-10: in a window the rows run as Halo's text commands.
        let view = HaloTextInspector(model: project).environment(\.haloText, { _ in })
        let controls = try textControls(view)
        for id in TextStyleRows.controlIDs { #expect(controls.contains { $0.id == id }, "no \(id)") }
        for control in controls { #expect(control.enabled, "\(control.id): \(control.reason ?? "nil")") }
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                view.padding(.vertical, SuiteSpacing.m)
                    .frame(width: SuiteSize.inspectorWidth.ideal)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(SuiteColor.panel),
                name: "halo-text-style-rows-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
#endif
