// FlareFixtures.swift: the fixture documents fakes, journeys and snapshots open (docs/blueprints/flare.md, section 4,
// Fixtures). Built in code, never read from disk; each fixture past `empty` has its own file under `Fixtures/`.
import FlareCore

public enum FlareFixtures {
    /// One 550 × 400 scene at 24 fps, 48 frames, no layers.
    public static let empty = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1")])

    /// Every fixture by its `-FlareFixture` name, in menu order.
    public static let all: [(name: String, document: Document)] = [("empty", empty), ("bounce", bounce)]

    /// The fixture called `name`, or nil.
    public static func named(_ name: String) -> Document? {
        all.first { $0.name == name }?.document
    }
}
