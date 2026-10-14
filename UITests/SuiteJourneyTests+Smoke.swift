// SuiteJourneyTests+Smoke.swift: proves the Journey template compiles a
// second journey file into a bundle (UITests/<target>*.swift, #333). It opens
// the gallery index and takes one shot; the CI log lists
// SuiteSmokeJourneys.testSecondFileRuns from this file.
import XCTest

final class SuiteSmokeJourneys: XCTestCase {
    @MainActor func testSecondFileRuns() {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.shot("index-smoke")
    }
}
