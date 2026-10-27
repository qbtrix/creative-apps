// PendingAdjustTarget.swift (adjust-everywhere AJ-3, AJ-4): the adjust target
// an app shows its Filter menu, FilterSheet and LookGrid on until its
// workspace adopts AdjustTarget (AJ-8). Every adjust and filter command is off
// with `reason`, and a run throws NotBuilt; the look store is the app's own,
// so Save Look… and Delete work on it.
import SuiteImaging
import SuiteKernel
import SuiteModel

public struct PendingAdjustTarget: AdjustTarget {
    public let reason: String
    /// Where Save Look… writes until the workspace's own store is wired.
    public let looks: any PresetStoring

    public init(reason: String = "Filters arrive with AJ-5.", looks: any PresetStoring = FakePresetStore()) {
        (self.reason, self.looks) = (reason, looks)
    }

    public var adjustHelp: String? { reason }
    public var filterHelp: String? { reason }
    public var currentLook: LookPreset { LookPreset(id: "current", name: "Current") }
    public var kinds: [ImagingKind] { [] }
    public mutating func setKinds(_ k: [ImagingKind], name: String) throws { throw CatalogError.notBuilt(id: "adjust", feature: "adjust-everywhere AJ-8") }
    public mutating func applyFilter(_ f: ImagingFilter, name: String) throws { throw CatalogError.notBuilt(id: "adjust", feature: "adjust-everywhere AJ-8") }
    public mutating func applyLook(_ l: LookPreset, name: String) throws { throw CatalogError.notBuilt(id: "adjust", feature: "adjust-everywhere AJ-8") }
}
