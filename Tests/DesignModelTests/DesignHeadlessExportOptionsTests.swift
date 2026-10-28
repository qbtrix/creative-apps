// DesignHeadlessExportOptionsTests.swift: the CLI's SVG export reads its `--json` options (quality gate #5834).
// SVG writes each frame at its own size, so a size other than 1x, or any key the suite's schema lacks, is
// refused in words (`ExportOptionRefusal`, bad input) instead of being ignored while the export says ok. Linux-safe.
@testable import DesignModel
import Foundation
import SuiteKernel
import Testing

@Suite struct DesignHeadlessExportOptionsTests {
    static func doc() throws -> DesignHeadless {
        try DesignHeadless.open(DesignHeadlessTests.input("export-frames-svg", "loose-front.design"), name: "loose-front.design")
    }

    static func json(_ text: String) throws -> JSONValue { try JSONValue(json: Data(text.utf8)) }

    @Test(arguments: [#"{"size":{"pixels":[1080,1350]}}"#, #"{"size":{"scale":2}}"#, #"{"size":{"longEdge":2048}}"#, #"{"colour":"red"}"#])
    func aSizeSVGCannotWriteIsRefused(_ options: String) throws {
        let doc = try Self.doc()
        #expect(throws: ExportOptionRefusal.self) { try doc.export("svg", options: Self.json(options)) }
    }

    @Test(arguments: ["null", "{}", #"{"size":{"scale":1}}"#])
    func noOptionsOrOneXExports(_ options: String) throws {
        #expect(try !Self.doc().export("svg", options: Self.json(options)).isEmpty)
    }
}
