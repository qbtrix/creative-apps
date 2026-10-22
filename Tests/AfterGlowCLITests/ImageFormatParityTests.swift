// ImageFormatParityTests.swift: the formats the suite writes are listed once
// (shared-codecs SC-13, written first; SC-14 turns it on). SuiteModel's
// `SuiteImageFormats.writable` names them; SuiteKernel's `ExportFormats.all`
// keeps what each can carry (quality, alpha, metadata). Its still rows and the
// registry's writable ids must be the same set, so neither list drifts.
import SuiteKernel
import SuiteModel
import Testing

@Suite(.disabled("waits on SC-14")) struct ImageFormatParityTests {
    /// ExportFormats.all's still rows' ids.
    static var stillIDs: Set<String> { Set(ExportFormats.all.filter { $0.kind == .still }.map(\.id)) }

    /// The writable ids equal the still export ids.
    @Test func writableIDsAreTheStillExportIDs() {
        #expect(Self.stillIDs == ["png", "jpeg", "heic", "tiff"])
        Issue.record("waits on SC-14: compare with SuiteImageFormats.writable")
    }
}
