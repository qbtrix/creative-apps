// PhotoBucketOptions.swift: the Paint Bucket's options in the inspector
// (fill-heal FH-3): Tolerance, Contiguous and All Layers, kept as
// SuiteImaging's `BucketOptions` on the workspace. Each change arrives as one
// `BucketOptionEdit`; the tolerance clamps to 0...255. Choosing options is not
// a document edit, so it is not undoable. Linux-safe.
import SuiteImaging

/// One change the Paint Bucket's options can ask for.
public enum BucketOptionEdit: Sendable, Equatable {
    /// How far a colour may sit from the clicked one and still fill, 0...255.
    case tolerance(Int)
    /// True fills only the region connected to the click; false every match.
    case contiguous(Bool)
    /// True reads the merged picture; the fill still lands on the selected layer.
    case sampleAllLayers(Bool)
}

extension PhotoWorkspace {
    /// The range the Tolerance slider shows.
    public static let bucketToleranceRange: ClosedRange<Double> = 0...255

    /// Changes one of the Paint Bucket's options.
    public mutating func setBucketOption(_ edit: BucketOptionEdit) {
        var options = bucketOptions
        switch edit {
        case .tolerance(let value): options.tolerance = min(255, max(0, value))
        case .contiguous(let on): options.contiguous = on
        case .sampleAllLayers(let on): options.sampleAllLayers = on
        }
        bucketOptions = options
    }
}
