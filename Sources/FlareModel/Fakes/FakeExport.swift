// FakeExport.swift: the fakes' `Exporting` (docs/blueprints/flare.md, 6.3; flare-export FX-8): `LiveExportAdapter`
// over `FakeStage`, so the SVG and Lottie bytes are FlareCore's real exports and each PNG frame comes from the fake
// stage through the rasterizer, with a 20 ms pause after it by default so Cancel is reachable. `unavailable` scans
// nothing and throws itself.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

public struct FakeExport: Exporting {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    /// The pause after each PNG frame; `.zero` runs straight through (the budget tests).
    public var frameDelay: Duration

    public init(unavailable: String? = nil, frameDelay: Duration = .milliseconds(20)) {
        self.unavailable = unavailable; self.frameDelay = frameDelay
    }

    private var adapter: LiveExportAdapter { LiveExportAdapter(stage: FakeStage(), frameDelay: frameDelay) }

    public func warnings(_ document: Document, options: ExportOptions) -> [String] {
        unavailable == nil ? adapter.warnings(document, options: options) : []
    }

    public func export(_ document: Document, options: ExportOptions, rasterizer: any FrameRasterizing,
                       progress: @Sendable (Double) -> Void) async throws -> ExportResult {
        if let unavailable { throw NotBuilt(reason: unavailable) }
        return try await adapter.export(document, options: options, rasterizer: rasterizer, progress: progress)
    }
}
