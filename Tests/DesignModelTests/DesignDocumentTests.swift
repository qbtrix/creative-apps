// DesignDocumentTests.swift: DesignDocument's defaults and equality, and a compile check that
// every use-case protocol in Contracts/UseCases.swift has exactly blueprint 5.4's signatures:
// `Stub` writes each requirement as 5.4 does, so a protocol whose signature drifts no longer
// accepts it. Runs on Linux and macOS.
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
        let transforming: any SelectionTransforming = Stub()
        #expect(transforming.transformHelp(["node-1"], on: page) == "Stub isn't built yet.")
        #expect(throws: DesignRefusal.notBuilt("Stub")) {
            try transforming.move(["node-1"], by: DesignPoint(x: 1, y: 0), on: page)
        }
        let filing: any DocumentFiling = Stub()
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
