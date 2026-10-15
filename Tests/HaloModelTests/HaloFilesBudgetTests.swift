// HaloFilesBudgetTests.swift: HB-10 (history-files packet), Save and Open on
// `crowd` (300 layers, 5,000 keys) on the live services: `fileData()`, and
// `decode` plus `finishOpen`, each under 50 ms on a device and 500 ms in
// debug CI. And `huge` encodes within 48 MiB, under the 64 MiB open limit
// (encode only: a debug Linux decode of 2,000 layers is too slow for the
// gate; H-J10 opens `huge` in the real app). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HaloModel
import Testing

struct HaloFilesBudgetTests {
    @Test func hugeFitsTheLimit() throws {
        let huge = try #require(HaloFixtures.project("huge"))
        let project = HaloProject(services: .live, document: huge)
        let data = try project.fileData()
        #expect(data.count <= 48 * 1024 * 1024)
    }

    @Test func saveCrowd() throws {
        let project = HaloProject(services: .live, document: try #require(HaloFixtures.project("crowd")))
        let budget = haloBudget(device: 50)
        var failed = false
        let cost = haloP95("saveCrowd", budget: budget) {
            if (try? project.fileData()) == nil { failed = true }
        }
        #expect(!failed)
        #expect(cost <= budget)
    }

    @Test func openCrowd() throws {
        let crowd = try #require(HaloFixtures.project("crowd"))
        var project = HaloProject(services: .live)
        let data = try LiveProjectFiles().encode(crowd)
        let budget = haloBudget(device: 50)
        var problems: [any Error] = []
        let cost = haloP95("openCrowd", budget: budget) {
            project.beginOpen(name: "Crowd", path: "/t/Crowd.halo")
            do {
                project.finishOpen(.success(try project.services.files.decode(data)))
            } catch {
                problems.append(error)
                project.finishOpen(.failure(.newerVersion(0)))
            }
        }
        #expect(problems.isEmpty, "decode threw \(problems.first.map { "\($0)" } ?? ""), e.g. .tooLarge")
        #expect(cost <= budget)
        #expect(project.document == crowd)
        #expect(!project.file.opening)
    }
}
