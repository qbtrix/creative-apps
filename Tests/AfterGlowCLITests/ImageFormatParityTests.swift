// ImageFormatParityTests.swift: the formats the suite writes are listed once
// (shared-codecs SC-13 wrote it, SC-14 turned it on). SuiteModel's
// `SuiteImageFormats.writable` names them; SuiteKernel's `ExportFormats.all`
// keeps what each can carry (quality, alpha, metadata). Its still rows and the
// registry's writable ids must be the same set, so neither list drifts.
import SuiteKernel
import SuiteModel
import Testing

@Suite struct ImageFormatParityTests {
    /// ExportFormats.all's still rows' ids.
    static var stillIDs: Set<String> { Set(ExportFormats.all.filter { $0.kind == .still }.map(\.id)) }

    /// The writable ids equal the still export ids.
    @Test func writableIDsAreTheStillExportIDs() {
        #expect(Set(SuiteImageFormats.writable.map(\.rawValue)) == Self.stillIDs)
        #expect(Self.stillIDs == ["png", "jpeg", "heic", "tiff"])
    }
}
