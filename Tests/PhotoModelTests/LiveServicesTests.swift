// LiveServicesTests.swift: `PhotoServices.live` holds no fake, each member
// that isn't built yet names its own feature, and `.fake` never shares an
// instance (blueprint 5.2). It keeps passing as each feature replaces its
// NotBuilt stand-in, and prints which are left. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct LiveServicesTests {
    /// Each member of `services` with the PV feature that builds it.
    private func members(_ services: PhotoServices) -> [(name: String, feature: String, value: any PhotoUseCase)] {
        [
            ("archive", "PV-1", services.archive), ("recovery", "PV-1", services.recovery),
            ("clipboard", "PV-2", services.clipboard), ("merging", "PV-2", services.merging),
            ("crop", "PV-3", services.crop), ("selection", "PV-5", services.selection),
            ("masking", "PV-5", services.masking), ("adjustmentLayers", "PV-6", services.adjustmentLayers),
            ("transform", "PV-7", services.transform), ("exportSizing", "PV-8", services.exportSizing),
            ("sampling", "PV-9", services.sampling),
        ]
    }

    @Test func liveHoldsNoFake() {
        for member in members(.live) {
            let type = String(describing: Swift.type(of: member.value))
            #expect(!type.hasPrefix("Fake"), "\(member.name) is \(type) on .live")
        }
    }

    @Test func liveHelpNamesEachMembersFeature() {
        var notBuilt: [String] = []
        for member in members(.live) {
            guard let help = member.value.unavailableHelp else { continue }
            #expect(help == "Not built yet (\(member.feature)).", "\(member.name): \(help)")
            notBuilt.append("\(member.name) (\(member.feature))")
        }
        print("PhotoServices.live still NotBuilt: \(notBuilt.isEmpty ? "none" : notBuilt.joined(separator: ", "))")
    }

    @Test func fakeMakesNewInstancesOnEveryRead() {
        let first = PhotoServices.fake.archive as? FakeArchive
        let second = PhotoServices.fake.archive as? FakeArchive
        #expect(first != nil && second != nil)
        #expect(first !== second)
        #expect((PhotoServices.fake.recovery as? FakeRecovery) !== (PhotoServices.fake.recovery as? FakeRecovery))
        for member in members(.fake) { #expect(member.value.unavailableHelp == nil, "\(member.name)") }
    }
}
