// HaloSaveTargetTests.swift: the save decision (HaloFiles.swift, HF-9). A
// launch path always writes without asking; Save writes the file the project
// was saved to or asks; Save As… always asks. The file name is the path's
// last component without ".halo", and after a save the title and status read
// what the window shows; a failed save reads Not saved with or without an
// edit, a failed open keeps the status it had. Runs on Linux and macOS.
import HaloModel
import Testing

private func empty() throws -> HaloProject {
    HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
}

@Test func aLaunchPathWritesWithoutAsking() throws {
    let project = try empty()
    #expect(project.saveTarget(launchPath: "/t/Spot.halo", saveAs: false) == .write(path: "/t/Spot.halo"))
    #expect(project.saveTarget(launchPath: "/t/Spot.halo", saveAs: true) == .write(path: "/t/Spot.halo"))
}

@Test func saveAsksUntilTheProjectHasAFile() throws {
    var project = try empty()
    #expect(project.saveTarget(launchPath: nil, saveAs: false) == .ask)
    project.didSave(name: "Spot", path: "/t/Spot.halo")
    #expect(project.saveTarget(launchPath: nil, saveAs: false) == .write(path: "/t/Spot.halo"))
    #expect(project.saveTarget(launchPath: nil, saveAs: true) == .ask)
}

@Test func theFileNameDropsTheFolderAndExtension() {
    #expect(HaloProject.fileName(fromPath: "/t/Spot.halo") == "Spot")
    #expect(HaloProject.fileName(fromPath: "Spot.halo") == "Spot")
    #expect(HaloProject.fileName(fromPath: "/t/Spot.HALO") == "Spot")
    #expect(HaloProject.fileName(fromPath: "/t/Spot.json") == "Spot.json")
    #expect(HaloProject.fileName(fromPath: "/t/My.Spot.halo") == "My.Spot")
    #expect(HaloProject.fileName(fromPath: "/t/dir/") == "dir")
    #expect(HaloProject.fileName(fromPath: "/t/.halo") == ".halo")
}

@Test func aSaveTitlesTheWindowAndAFailedSaveReadsNotSaved() throws {
    var project = try empty()
    project.didSave(name: HaloProject.fileName(fromPath: "/t/Spot.halo"), path: "/t/Spot.halo")
    #expect(project.windowTitle == "Spot")
    #expect(project.saveStatus == "Saved")
    project.didFailSave("Spot.halo can't be saved. The folder is read-only.")
    #expect(project.saveStatus == "Not saved")
    #expect(project.windowSubtitle == "Not saved")
    #expect(project.windowTitle == "Spot")
    #expect(project.saveTarget(launchPath: nil, saveAs: false) == .write(path: "/t/Spot.halo"))
}

@Test func aFailedSaveWithNoEditReadsNotSaved() throws {
    var project = try empty()
    #expect(project.saveStatus == "Untitled")
    project.didFailSave("Untitled Project.halo can't be saved. The folder is read-only.")
    #expect(project.saveStatus == "Not saved")
    #expect(project.file.unsaved)
}

@Test func aFailedOpenKeepsItsStatus() throws {
    var project = try empty()
    project.beginOpen(name: "Bad", path: "/t/Bad.halo")
    project.finishOpen(.failure(.notAHaloFile))
    #expect(project.saveStatus == "Untitled")
    #expect(!project.file.unsaved)
    #expect(project.windowSubtitle == nil)
}
