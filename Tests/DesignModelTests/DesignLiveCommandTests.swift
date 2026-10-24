// DesignLiveCommandTests.swift (editor-menus EM-4): the window adopts a live
// command's copy of its workspace, and ignores a copy of another file. Runs on
// Linux and macOS.
import DesignModel
import Foundation
import SuiteKernel
import Testing

struct DesignLiveCommandTests {
    @Test func aLiveCommandsResultIsAdopted() throws {
        var window = try DesignHeadless.new(.object([:])).workspace
        var copy = DesignHeadless(window)
        _ = try DesignHeadless.catalog.run("page.add", params: .object([:]), on: &copy)
        window.adoptLiveCommand(copy.workspace)
        #expect(window.pages.count == 2)
        #expect(window == copy.workspace)
    }

    @Test func aCopyOfAnotherFileIsIgnored() throws {
        var window = try DesignHeadless.new(.object([:])).workspace
        var other = DesignWorkspace()
        try other.open(DesignHeadless(window).save(), at: URL(fileURLWithPath: "/t/other.design"))
        var copy = DesignHeadless(other)
        _ = try DesignHeadless.catalog.run("page.add", params: .object([:]), on: &copy)
        window.adoptLiveCommand(copy.workspace)
        #expect(window.pages.count == 1)
        #expect(window.documentURL == nil)
    }
}
