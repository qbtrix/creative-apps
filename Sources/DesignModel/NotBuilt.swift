// NotBuilt.swift: the conformance a use case has before its feature lands. Every
// help is "<Feature> isn't built yet.", every write throws `.notBuilt(feature)`,
// and every read answers nothing (no layers, no rect, no resolved value), so a
// control on it is disabled and never acts. The file codec refuses both ways:
// encode with `.noFile`, decode with `.unreadable`. DesignServices.live is
// NotBuilt in every slot until each live type lands. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Every use case, refusing with `.notBuilt(feature)`; every help says so.
public struct NotBuilt: Sendable {
    public let feature: String
    public init(_ feature: String) { self.feature = feature }
    var refusal: DesignRefusal { .notBuilt(feature) }
    var help: String { refusal.help }
}

extension NotBuilt: MarqueeSelecting {
    public func layers(touching rect: DesignRect, in parentID: String?, on page: DesignPage) -> [String] { [] }
}

extension NotBuilt: SelectionTransforming {
    public func transformHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func move(_ ids: [String], by delta: DesignPoint, on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func resize(_ ids: [String], handle: DesignHandle, by delta: DesignPoint, modifiers: DesignModifiers,
                       on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func nudge(_ ids: [String], _ direction: DesignDirection, large: Bool, on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func delete(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: LayerAligning {
    public func alignHelp(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) -> String? { help }
    public func align(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func distributeHelp(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) -> String? { help }
    public func distribute(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: LayerDuplicating {
    public func duplicateHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func duplicate(_ ids: [String], offset: DesignPoint, on page: DesignPage,
                          mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func copySubtree(_ node: DesignNode, mint: inout DesignIDMint) -> DesignNode { node }
}

extension NotBuilt: LayerGrouping {
    public func groupHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func group(_ ids: [String], on page: DesignPage, mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func ungroupHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func ungroup(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: LayerClipboard {
    public var pasteboardType: String { "org.creativesuite.design.layers" }
    public func copyHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func encode(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> Data { throw refusal }
    public func pasteHelp(_ data: Data?) -> String? { help }
    public func paste(_ data: Data, into parentID: String?, on page: DesignPage,
                      mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: LayerOrdering {
    public func moveHelp(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) -> String? { help }
    public func move(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func arrangeHelp(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) -> String? { help }
    public func arrange(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: StyleEditing {
    public func styleHelp(_ property: DesignStyleProperty, _ ids: [String], on page: DesignPage) -> String? { help }
    public func setFrame(_ field: DesignFrameField, to value: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func setFill(_ color: DesignColor, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func setCornerRadius(_ radius: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func setOpacity(_ opacity: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func setStroke(_ stroke: DesignStroke?, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func setTextStyle(_ style: DesignTextStyle, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: ViewFraming {
    public func framingHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func rectToShow(_ ids: [String], on page: DesignPage) -> DesignRect? { nil }
}

extension NotBuilt: DocumentFiling {
    public func encode(_ document: DesignDocument) throws(DesignFileError) -> Data { throw .noFile }
    public func decode(_ data: Data) throws(DesignFileError) -> DesignDocument { throw .unreadable }
}

extension NotBuilt: ExportPlanning {
    public func exportHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func plan(_ ids: [String], on page: DesignPage, format: DesignExportFormat, scale: Int,
                     existing: Set<String>) throws(DesignRefusal) -> [DesignExportItem] { throw refusal }
    public func svg(for id: String, on page: DesignPage) throws(DesignRefusal) -> String { throw refusal }
}

extension NotBuilt: PathDrawing {
    public func press(at point: DesignPoint, draft: DesignPath?, tolerance: Double) -> DesignPath {
        draft ?? DesignPath(anchors: [], isClosed: false)
    }
    public func dragHandle(to point: DesignPoint, draft: DesignPath) -> DesignPath { draft }
    public func bounds(of path: DesignPath) -> DesignRect? { nil }
    public func commit(_ draft: DesignPath, into parentID: String?, on page: DesignPage,
                       mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw refusal }
}

extension NotBuilt: ComponentLibrary {
    public func createHelp(_ ids: [String], on page: DesignPage) -> String? { help }
    public func create(from id: String, on page: DesignPage, library: [DesignComponent],
                       mint: inout DesignIDMint) throws(DesignRefusal) -> (edit: DesignEdit, library: [DesignComponent]) { throw refusal }
    public func insert(_ componentID: String, centeredOn center: DesignPoint, on page: DesignPage,
                       library: [DesignComponent], mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit { throw refusal }
    public func resolve(_ instance: DesignNode, library: [DesignComponent]) -> [DesignNode]? { nil }
}

extension NotBuilt: VariableEditing {
    public func add(named name: String, value: DesignVariableValue, to variables: [DesignVariable],
                    id: String) throws(DesignRefusal) -> [DesignVariable] { throw refusal }
    public func rename(_ id: String, to name: String, in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] { throw refusal }
    public func remove(_ id: String, from variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] { throw refusal }
    public func set(_ id: String, _ mode: DesignMode, to value: DesignVariableValue,
                    in variables: [DesignVariable]) throws(DesignRefusal) -> [DesignVariable] { throw refusal }
    public func resolve(_ id: String, in mode: DesignMode, variables: [DesignVariable]) -> DesignVariableValue? { nil }
    public func bind(_ variableID: String?, _ ids: [String], on page: DesignPage,
                     variables: [DesignVariable]) throws(DesignRefusal) -> DesignEdit { throw refusal }
}
