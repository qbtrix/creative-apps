// HaloFillColorAvailabilityTests.swift: the inspector's FILL color row
// (`setLayerColor`) is on for every layer `setLayerColor` can color (text,
// solid, shape), while the text-only commands (field, size, size scrub) keep
// "Select a text layer first." on a solid or shape. A null takes no color, so
// the row stays off there. Linux and macOS.
@testable import HaloModel
import Testing

@Suite struct HaloFillColorAvailabilityTests {
    private static let color = HaloCommand.setLayerColor(HaloLayerColor(red: 1, green: 0, blue: 0))
    private static let textOnly: [HaloCommand] = [.setText("Hello"), .setFontSize(48), .endTextSizeScrub]

    /// `empty` on `services` with a new `kind` layer selected.
    private static func project(_ kind: HaloLayerKind, _ services: HaloServices) throws -> HaloProject {
        var project = HaloProject(services: services)
        project.restore(try #require(HaloFixtures.project("empty")))
        project.newLayer(kind)
        #expect(project.selectedLayer?.kind == kind)
        return project
    }

    @Test(arguments: [HaloServices.fake, .live], [HaloLayerKind.solid, .shape])
    func theColorRowIsOnForASolidOrShape(services: HaloServices, kind: HaloLayerKind) throws {
        let project = try Self.project(kind, services)
        #expect(project.unavailableHelp(for: Self.color) == nil, "color on \(kind)")
        for command in Self.textOnly {
            #expect(project.unavailableHelp(for: command) == "Select a text layer first.", "\(command) on \(kind)")
        }
    }

    @Test(arguments: [HaloServices.fake, .live])
    func theColorRowIsOffOnANullOrNoLayer(services: HaloServices) throws {
        var project = HaloProject(services: services)
        project.restore(try #require(HaloFixtures.project("empty")))
        #expect(project.unavailableHelp(for: Self.color) != nil, "no layer")
        project.newLayer(.null)
        #expect(project.unavailableHelp(for: Self.color) != nil, "on a null")
    }
}
