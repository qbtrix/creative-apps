// SupportFolderRatchetTests.swift: one support root (adopt-kernel-autosave
// AK-1, rule 20). Every `.swift` under `Sources/` but SuiteLocations.swift
// that names the Application Support directory must be listed in
// `Tests/support-dir-baseline.txt`. A listed file with no hit is fine, so the
// slices shrink the list by moving code, and AK-11 deletes the list so any hit
// fails. Files are read by path from #filePath.
import Foundation
import Testing

enum SupportFolderScan {
    /// The text a hit names (split so this test file never matches itself).
    static let needle = "applicationSupport" + "Directory"
    /// The one file allowed to name it.
    static let owner = "Sources/SuiteModel/Store/SuiteLocations.swift"

    /// The paths in `files` (path to text) that name the needle, but the owner, sorted.
    static func hits(_ files: [String: String]) -> [String] {
        files.filter { $0.key != owner && $0.value.contains(needle) }.map(\.key).sorted()
    }

    /// The baseline's paths: one per line, `#` comments and blank lines skipped.
    static func listed(_ baseline: String) -> Set<String> {
        Set(baseline.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") })
    }

    /// One message per hit the baseline doesn't list.
    static func problems(_ files: [String: String], baseline: String) -> [String] {
        let allowed = listed(baseline)
        return hits(files).filter { !allowed.contains($0) }.map {
            "\($0) names the Application Support directory; take the folder from SuiteLocations.appFolder"
        }
    }

    /// Every `.swift` under `root/Sources`, by path relative to root.
    static func sources(root: URL) throws -> [String: String] {
        let base = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else { return [:] }
        var files: [String: String] = [:]
        while let path = walker.nextObject() as? String {
            guard path.hasSuffix(".swift") else { continue }
            files["Sources/" + path] = try String(contentsOf: base.appendingPathComponent(path), encoding: .utf8)
        }
        return files
    }
}

@Suite struct SupportFolderRatchetTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static func baseline() throws -> String {
        try String(contentsOf: root.appendingPathComponent("Tests/support-dir-baseline.txt"), encoding: .utf8)
    }
    static let call = "FileManager.default.urls(for: ." + SupportFolderScan.needle + ", in: .userDomainMask)"

    /// A new Application Support path in HaloModel fails, by file, even with today's baseline.
    @Test func newHitFails() throws {
        let files = ["Sources/HaloModel/HaloFixture.swift": "let support = \(Self.call).first"]
        #expect(SupportFolderScan.problems(files, baseline: try Self.baseline())
            == ["Sources/HaloModel/HaloFixture.swift names the Application Support directory; take the folder from SuiteLocations.appFolder"])
    }

    /// SuiteLocations.swift may name it; a file without a hit never fails.
    @Test func ownerAndCleanFilesPass() {
        let files = [SupportFolderScan.owner: Self.call, "Sources/HaloModel/Clean.swift": "let a = 1"]
        #expect(SupportFolderScan.problems(files, baseline: "").isEmpty)
    }

    /// A listed file with no hit is fine, so a slice can shrink the tree before the list.
    @Test func listedFileWithoutHitPasses() {
        let files = ["Sources/PhotoModel/Live/LiveRecovery.swift": "let a = 1"]
        #expect(SupportFolderScan.problems(files, baseline: "# c\nSources/PhotoModel/Live/LiveRecovery.swift\n").isEmpty)
    }

    /// Today's tree passes against the baseline, and the baseline names real hits.
    @Test func realTreePasses() throws {
        let files = try SupportFolderScan.sources(root: Self.root)
        #expect(!files.isEmpty)
        let problems = SupportFolderScan.problems(files, baseline: try Self.baseline())
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }
}
