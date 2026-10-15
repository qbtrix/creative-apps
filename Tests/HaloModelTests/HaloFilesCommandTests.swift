// HaloFilesCommandTests.swift: HF-7 (history-files packet). Open…, Open
// Recent, Save and Save As… act or say why: no composition to save, no
// recent project, or a project opening. Runs on Linux and macOS.
import HaloModel
import Testing

private let fileCommands: [HaloCommand] = [.open, .openRecent("/t/Spot.halo"), .save, .saveAs]

struct HaloFilesCommandTests {
    @Test func aNewProjectCanOnlyOpen() {
        let project = HaloProject(services: .live)
        #expect(project.unavailableHelp(for: .save) == "Create a composition first.")
        #expect(project.unavailableHelp(for: .saveAs) == "Create a composition first.")
        #expect(project.unavailableHelp(for: .openRecent("/t/Spot.halo")) == "No recent projects.")
        #expect(project.unavailableHelp(for: .open) == nil)
    }

    @Test func aCompositionCanBeSaved() throws {
        let project = HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
        #expect(project.unavailableHelp(for: .save) == nil)
        #expect(project.unavailableHelp(for: .saveAs) == nil)
        #expect(project.unavailableHelp(for: .open) == nil)
        #expect(project.unavailableHelp(for: .openRecent("/t/Spot.halo")) == "No recent projects.")
    }

    @Test func aSavedProjectIsRecent() throws {
        var project = HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
        project.didSave(name: "Spot", path: "/t/Spot.halo")
        #expect(project.unavailableHelp(for: .openRecent("/t/Spot.halo")) == nil)
    }

    @Test func nothingActsWhileOpening() throws {
        var project = HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
        project.didSave(name: "Spot", path: "/t/Spot.halo")
        project.beginOpen(name: "Next", path: "/t/Next.halo")
        for command in fileCommands {
            #expect(project.unavailableHelp(for: command) == "A project is opening.")
        }
    }

    @Test func thePendingOpenIsNotARecentProject() throws {
        var project = HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
        project.beginOpen(name: "Next", path: "/t/Next.halo")
        project.finishOpen(.failure(.newerVersion(2)))
        #expect(project.unavailableHelp(for: .openRecent("/t/Next.halo")) == "No recent projects.")
        #expect(project.unavailableHelp(for: .open) == nil)
    }

    @Test func everyFileCommandActsOrSaysWhy() throws {
        for name in HaloFixtures.names {
            let project = HaloProject(services: .live, document: try #require(HaloFixtures.project(name)))
            for command in HaloCommand.allCases where command.area == .files {
                let help = project.unavailableHelp(for: command)
                #expect(help != "Not built yet (#209).")
                #expect(help.map { !$0.isEmpty } ?? true)
            }
        }
    }
}
