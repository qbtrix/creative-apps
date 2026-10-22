// SuiteImaging: the suite's one imaging library (suite-imaging, IM-1). The
// adjustment values (Adjust/), the tone program they compile to, and the CPU
// or GPU route with its live tone surface (Route/) land here from IM-2 on. It
// is the only module outside SuiteUI's canvas host that may import Metal, and
// only on macOS (Tests/SuiteImagingTests/ImagingBoundaryTests).
public enum SuiteImaging {
    /// The contract version of this library's public values.
    public static let version = 1
}
