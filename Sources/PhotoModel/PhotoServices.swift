// PhotoServices.swift: one value per v2 use case, the seam between the
// window and the logic. `.fake` runs every contract on its fake, so views and
// journeys are built before the logic (`-PhotoFixture`). `.live` takes each
// member from its Live file, where a feature that isn't built yet returns
// its NotBuilt stand-in, whose `unavailableHelp` disables the controls that
// need it. Linux-safe.
public struct PhotoServices: Sendable {
    public var archive: any DocumentArchiving
    public var recovery: any RecoveryStoring
    public var clipboard: any PixelClipboard
    public var merging: any LayerMerging
    public var crop: any CropSizing
    public var selection: any SelectionShaping
    public var masking: any LayerMasking
    public var adjustmentLayers: any AdjustmentLayering
    public var transform: any LayerTransforming
    public var exportSizing: any ExportSizing
    public var sampling: any ColorSampling

    public init(archive: any DocumentArchiving, recovery: any RecoveryStoring, clipboard: any PixelClipboard,
                merging: any LayerMerging, crop: any CropSizing, selection: any SelectionShaping,
                masking: any LayerMasking, adjustmentLayers: any AdjustmentLayering,
                transform: any LayerTransforming, exportSizing: any ExportSizing, sampling: any ColorSampling) {
        self.archive = archive; self.recovery = recovery; self.clipboard = clipboard; self.merging = merging
        self.crop = crop; self.selection = selection; self.masking = masking
        self.adjustmentLayers = adjustmentLayers; self.transform = transform
        self.exportSizing = exportSizing; self.sampling = sampling
    }

    /// Every use case on its fake: deterministic, instant, no file system.
    /// New instances on every read, so no two workspaces share a fake's state.
    public static var fake: PhotoServices {
        PhotoServices(
            archive: FakeArchive(), recovery: FakeRecovery(), clipboard: FakeClipboard(), merging: FakeMerging(),
            crop: FakeCrop(), selection: FakeSelection(), masking: FakeMasking(),
            adjustmentLayers: FakeAdjustmentLayers(), transform: FakeTransform(), exportSizing: FakeExportSizing(),
            sampling: FakeSampling())
    }

    /// Every use case on its live conformance, each from its feature's file
    /// in `Live/` (a NotBuilt stand-in until the feature lands). The
    /// workspace's default.
    public static var live: PhotoServices {
        PhotoServices(
            archive: LiveDocuments.archive(), recovery: LiveDocuments.recovery(), clipboard: LiveEdit.clipboard(),
            merging: LiveEdit.merging(), crop: LiveCrop.make(), selection: LiveSelection.selection(),
            masking: LiveSelection.masking(), adjustmentLayers: LiveAdjustmentLayers.make(),
            transform: LiveTransform.make(), exportSizing: LiveExportSizing.make(), sampling: LiveSampling.make())
    }
}
