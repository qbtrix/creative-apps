// DesignDocumentTests.swift: DesignDocument's defaults and equality, and a compile check that
// every use-case protocol in Contracts/UseCases.swift has blueprint 5.4's signatures. `Stub`
// conforms to all 14 protocols, and `everyUseCaseIsSatisfiableAsWritten` binds every requirement
// through `any P` to a function value typed as 5.4 writes it, so a requirement that is removed,
// renamed, retyped, or loosened from a typed `throws(...)` to plain `throws` stops this file
// compiling. A narrowed requirement (a write that stops throwing, a `String?` help that becomes
// `String`) is caught by `Stub`'s conformance, whose witnesses no longer match; the existential
// pins catch loosening and removal. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
import DesignModel

@Suite struct DesignDocumentTests {
    @Test func pagesAloneLeaveComponentsAndVariablesEmpty() {
        let document = DesignDocument(pages: openDesign().pages)
        #expect(document.pages == openDesign().pages)
        #expect(document.components.isEmpty)
        #expect(document.variables.isEmpty)
    }

    @Test func equalityCoversPagesComponentsAndVariables() {
        let pages = openDesign().pages
        let card = DesignComponent(id: "component-1", name: "Card", width: 10, height: 10, nodes: [])
        let accent = DesignVariable(id: "variable-1", name: "Accent", light: .number(1), dark: .number(2))
        let document = DesignDocument(pages: pages, components: [card], variables: [accent])
        #expect(document == DesignDocument(pages: pages, components: [card], variables: [accent]))
        #expect(document != DesignDocument(pages: [], components: [card], variables: [accent]))
        #expect(document != DesignDocument(pages: pages, variables: [accent]))
        #expect(document != DesignDocument(pages: pages, components: [card]))
    }

    @Test func everyUseCaseIsSatisfiableAsWritten() throws {
        let page = try #require(openDesign().pages.first)

        // Tier 1.
        let marquee: any MarqueeSelecting = Stub()
        let _: (DesignRect, String?, DesignPage) -> [String] = marquee.layers(touching:in:on:)

        let transforming: any SelectionTransforming = Stub()
        let _: ([String], DesignPage) -> String? = transforming.transformHelp(_:on:)
        let _: ([String], DesignPoint, DesignPage) throws(DesignRefusal) -> DesignEdit = transforming.move(_:by:on:)
        let _: ([String], DesignHandle, DesignPoint, DesignModifiers, DesignPage) throws(DesignRefusal) -> DesignEdit
            = transforming.resize(_:handle:by:modifiers:on:)
        let _: ([String], DesignDirection, Bool, DesignPage) throws(DesignRefusal) -> DesignEdit = transforming.nudge(_:_:large:on:)
        let _: ([String], DesignPage) throws(DesignRefusal) -> DesignEdit = transforming.delete(_:on:)

        let aligning: any LayerAligning = Stub()
        let _: (DesignAlignEdge, [String], DesignPage) -> String? = aligning.alignHelp(_:_:on:)
        let _: (DesignAlignEdge, [String], DesignPage) throws(DesignRefusal) -> DesignEdit = aligning.align(_:_:on:)
        let _: (DesignDistributeAxis, [String], DesignPage) -> String? = aligning.distributeHelp(_:_:on:)
        let _: (DesignDistributeAxis, [String], DesignPage) throws(DesignRefusal) -> DesignEdit = aligning.distribute(_:_:on:)

        let duplicating: any LayerDuplicating = Stub()
        let _: ([String], DesignPage) -> String? = duplicating.duplicateHelp(_:on:)
        let _: ([String], DesignPoint, DesignPage, inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
            = duplicating.duplicate(_:offset:on:mint:)
        let _: (DesignNode, inout DesignIDMint) -> DesignNode = duplicating.copySubtree(_:mint:)

        let grouping: any LayerGrouping = Stub()
        let _: ([String], DesignPage) -> String? = grouping.groupHelp(_:on:)
        let _: ([String], DesignPage, inout DesignIDMint) throws(DesignRefusal) -> DesignEdit = grouping.group(_:on:mint:)
        let _: ([String], DesignPage) -> String? = grouping.ungroupHelp(_:on:)
        let _: ([String], DesignPage) throws(DesignRefusal) -> DesignEdit = grouping.ungroup(_:on:)

        let clipboard: any LayerClipboard = Stub()
        let _: String = clipboard.pasteboardType
        let _: ([String], DesignPage) -> String? = clipboard.copyHelp(_:on:)
        let _: ([String], DesignPage) throws(DesignRefusal) -> Data = clipboard.encode(_:on:)
        let _: (Data?) -> String? = clipboard.pasteHelp(_:)
        let _: (Data, String?, DesignPage, inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
            = clipboard.paste(_:into:on:mint:)

        let ordering: any LayerOrdering = Stub()
        let _: (String, String?, Int, DesignPage) -> String? = ordering.moveHelp(_:into:at:on:)
        let _: (String, String?, Int, DesignPage) throws(DesignRefusal) -> DesignEdit = ordering.move(_:into:at:on:)
        let _: (DesignArrangeStep, [String], DesignPage) -> String? = ordering.arrangeHelp(_:_:on:)
        let _: (DesignArrangeStep, [String], DesignPage) throws(DesignRefusal) -> DesignEdit = ordering.arrange(_:_:on:)

        let styling: any StyleEditing = Stub()
        let _: (DesignStyleProperty, [String], DesignPage) -> String? = styling.styleHelp(_:_:on:)
        let _: (DesignFrameField, Double, [String], DesignPage) throws(DesignRefusal) -> DesignEdit = styling.setFrame(_:to:_:on:)
        let _: (DesignColor, [String], DesignPage) throws(DesignRefusal) -> DesignEdit = styling.setFill(_:_:on:)
        let _: (Double, [String], DesignPage) throws(DesignRefusal) -> DesignEdit = styling.setCornerRadius(_:_:on:)
        let _: (Double, [String], DesignPage) throws(DesignRefusal) -> DesignEdit = styling.setOpacity(_:_:on:)
        let _: (DesignStroke?, [String], DesignPage) throws(DesignRefusal) -> DesignEdit = styling.setStroke(_:_:on:)
        let _: (DesignTextStyle, [String], DesignPage) throws(DesignRefusal) -> DesignEdit = styling.setTextStyle(_:_:on:)

        let framing: any ViewFraming = Stub()
        let _: ([String], DesignPage) -> String? = framing.framingHelp(_:on:)
        let _: ([String], DesignPage) -> DesignRect? = framing.rectToShow(_:on:)

        let filing: any DocumentFiling = Stub()
        let _: (DesignDocument) throws(DesignFileError) -> Data = filing.encode(_:)
        let _: (Data) throws(DesignFileError) -> DesignDocument = filing.decode(_:)

        // Tier 2.
        let exporting: any ExportPlanning = Stub()
        let _: ([String], DesignPage) -> String? = exporting.exportHelp(_:on:)
        let _: ([String], DesignPage, DesignExportFormat, Int, Set<String>) throws(DesignRefusal) -> [DesignExportItem]
            = exporting.plan(_:on:format:scale:existing:)
        let _: (String, DesignPage) throws(DesignRefusal) -> String = exporting.svg(for:on:)

        let drawing: any PathDrawing = Stub()
        let _: (DesignPoint, DesignPath?, Double) -> DesignPath = drawing.press(at:draft:tolerance:)
        let _: (DesignPoint, DesignPath) -> DesignPath = drawing.dragHandle(to:draft:)
        let _: (DesignPath) -> DesignRect? = drawing.bounds(of:)
        let _: (DesignPath, String?, DesignPage, inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
            = drawing.commit(_:into:on:mint:)

        let components: any ComponentLibrary = Stub()
        let _: ([String], DesignPage) -> String? = components.createHelp(_:on:)
        let _: (String, DesignPage, [DesignComponent], inout DesignIDMint) throws(DesignRefusal)
            -> (edit: DesignEdit, library: [DesignComponent]) = components.create(from:on:library:mint:)
        let _: (String, DesignPoint, DesignPage, [DesignComponent], inout DesignIDMint) throws(DesignRefusal) -> DesignEdit
            = components.insert(_:centeredOn:on:library:mint:)
        let _: (DesignNode, [DesignComponent]) -> [DesignNode]? = components.resolve(_:library:)

        let variables: any VariableEditing = Stub()
        let _: (String, DesignVariableValue, [DesignVariable], String) throws(DesignRefusal) -> [DesignVariable]
            = variables.add(named:value:to:id:)
        let _: (String, String, [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] = variables.rename(_:to:in:)
        let _: (String, [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] = variables.remove(_:from:)
        let _: (String, DesignMode, DesignVariableValue, [DesignVariable]) throws(DesignRefusal) -> [DesignVariable]
            = variables.set(_:_:to:in:)
        let _: (String, DesignMode, [DesignVariable]) -> DesignVariableValue? = variables.resolve(_:in:variables:)
        let _: (String?, [String], DesignPage, [DesignVariable]) throws(DesignRefusal) -> DesignEdit
            = variables.bind(_:_:on:variables:)

        // And through the existential at run time.
        #expect(transforming.transformHelp(["node-1"], on: page) == "Stub isn't built yet.")
        #expect(throws: DesignRefusal.notBuilt("Stub")) {
            try transforming.move(["node-1"], by: DesignPoint(x: 1, y: 0), on: page)
        }
        #expect(throws: DesignFileError.unreadable) { try filing.decode(Data()) }
    }
}

/// Every requirement as 5.4 writes it: helps answer "Stub isn't built yet.", writes refuse.
private struct Stub {
    static let refusal = DesignRefusal.notBuilt("Stub")
    var pasteboardType: String { "test.stub" }
}

private func help() -> String? { Stub.refusal.help }

extension Stub: MarqueeSelecting {
    func layers(touching rect: DesignRect, in parentID: String?, on page: DesignPage) -> [String] { [] }
}

extension Stub: SelectionTransforming {
    func transformHelp(_ ids: [String], on page: DesignPage) -> String? { help() }
    func move(_ ids: [String], by delta: DesignPoint, on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func resize(_ ids: [String], handle: DesignHandle, by delta: DesignPoint, modifiers: DesignModifiers,
                on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func nudge(_ ids: [String], _ direction: DesignDirection, large: Bool, on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func delete(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
}

extension Stub: LayerAligning {
    func alignHelp(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) -> String? { help() }
    func align(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func distributeHelp(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) -> String? { help() }
    func distribute(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
}

extension Stub: LayerDuplicating {
    func duplicateHelp(_ ids: [String], on page: DesignPage) -> String? { help() }
    func duplicate(_ ids: [String], offset: DesignPoint, on page: DesignPage,
                   mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func copySubtree(_ node: DesignNode, mint: inout DesignIDMint) -> DesignNode { node }
}

extension Stub: LayerGrouping {
    func groupHelp(_ ids: [String], on page: DesignPage) -> String? { help() }
    func group(_ ids: [String], on page: DesignPage, mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func ungroupHelp(_ ids: [String], on page: DesignPage) -> String? { help() }
    func ungroup(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
}

extension Stub: LayerClipboard {
    func copyHelp(_ ids: [String], on page: DesignPage) -> String? { help() }
    func encode(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> Data { throw Self.refusal }
    func pasteHelp(_ data: Data?) -> String? { help() }
    func paste(_ data: Data, into parentID: String?, on page: DesignPage,
               mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
}

extension Stub: LayerOrdering {
    func moveHelp(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) -> String? { help() }
    func move(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func arrangeHelp(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) -> String? { help() }
    func arrange(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
}

extension Stub: StyleEditing {
    func styleHelp(_ property: DesignStyleProperty, _ ids: [String], on page: DesignPage) -> String? { help() }
    func setFrame(_ field: DesignFrameField, to value: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func setFill(_ color: DesignColor, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func setCornerRadius(_ radius: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func setOpacity(_ opacity: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func setStroke(_ stroke: DesignStroke?, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func setTextStyle(_ style: DesignTextStyle, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
}

extension Stub: ViewFraming {
    func framingHelp(_ ids: [String], on page: DesignPage) -> String? { help() }
    func rectToShow(_ ids: [String], on page: DesignPage) -> DesignRect? { nil }
}

extension Stub: DocumentFiling {
    func encode(_ document: DesignDocument) throws(DesignFileError) -> Data { throw .noFile }
    func decode(_ data: Data) throws(DesignFileError) -> DesignDocument { throw .unreadable }
}

extension Stub: ExportPlanning {
    func exportHelp(_ ids: [String], on page: DesignPage) -> String? { help() }
    func plan(_ ids: [String], on page: DesignPage, format: DesignExportFormat, scale: Int,
              existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem] { throw Self.refusal }
    func svg(for id: String, on page: DesignPage) throws(DesignRefusal) -> String { throw Self.refusal }
}

extension Stub: PathDrawing {
    func press(at point: DesignPoint, draft: DesignPath?, tolerance: Double) -> DesignPath { DesignPath(anchors: [], isClosed: false) }
    func dragHandle(to point: DesignPoint, draft: DesignPath) -> DesignPath { draft }
    func bounds(of path: DesignPath) -> DesignRect? { nil }
    func commit(_ draft: DesignPath, into parentID: String?, on page: DesignPage,
                mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
}

extension Stub: ComponentLibrary {
    func createHelp(_ ids: [String], on page: DesignPage) -> String? { help() }
    func create(from id: String, on page: DesignPage, library: [DesignComponent],
                mint: inout DesignIDMint) throws(DesignRefusal) -> (edit: DesignEdit, library: [DesignComponent]) { throw Self.refusal }
    func insert(_ componentID: String, centeredOn center: DesignPoint, on page: DesignPage,
                library: [DesignComponent], mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
    func resolve(_ instance: DesignNode, library: [DesignComponent]) -> [DesignNode]? { nil }
}

extension Stub: VariableEditing {
    func add(named name: String, value: DesignVariableValue, to variables: [DesignVariable],
             id: String) throws(DesignRefusal) -> [DesignVariable] { throw Self.refusal }
    func rename(_ id: String, to name: String, in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] { throw Self.refusal }
    func remove(_ id: String, from variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] { throw Self.refusal }
    func set(_ id: String, _ mode: DesignMode, to value: DesignVariableValue,
             in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] { throw Self.refusal }
    func resolve(_ id: String, in mode: DesignMode, variables: [DesignVariable]) -> DesignVariableValue? { nil }
    func bind(_ variableID: String?, _ ids: [String], on page: DesignPage,
              variables: [DesignVariable]) throws(DesignRefusal) -> DesignEdit { throw Self.refusal }
}
