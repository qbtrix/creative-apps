// FlareExport+Kernel.swift: the export sheet's run transitions (docs/blueprints/flare/features/flare-export.md,
// Contract slice). FX-2a declares them as stubs that report nothing and change nothing, so the sheet (FX-3) builds
// against them; FX-4 fills the bodies over the kernel's export run without changing a signature.
import FlareCore

extension FlareWorkspace {
    /// The run's options in every state but idle. Stub (FX-4): nil.
    public var exportingOptions: ExportOptions? { nil }

    /// Idle to editing on the SVG frame defaults; false otherwise. Stub (FX-4): false, changing nothing.
    @discardableResult
    public mutating func openExport() -> Bool { false }

    /// Editing with no problem to running at 0 of `exportFileCount`; false otherwise. Stub (FX-4): false, changing nothing.
    @discardableResult
    public mutating func startExport() -> Bool { false }

    /// Failed back to editing with the same options. Stub (FX-4): changes nothing.
    public mutating func retryExport() {}
}
