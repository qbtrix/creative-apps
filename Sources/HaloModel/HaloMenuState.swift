// HaloMenuState.swift (adopt-command-catalog AC-h3): what a Halo menu item built from its catalog spec reads. The
// target is the focused window's project, nil with no Halo window (or none to send to), when every item is off with
// "Open a Halo window first.", as today's menus were. With a project each item is the catalog's availability, which is
// `unavailableHelp(for:)`; titles stay `title(for:)` ("Undo New Layer"). Run goes through the catalog. Linux-safe.
import SuiteKernel

public struct HaloMenuState: Sendable {
    public var project: HaloProject?

    public init(project: HaloProject?) { self.project = project }

    static let noWindow = "Open a Halo window first."

    /// The catalog's spec for `id` over the menu state; an id the catalog lacks is never available.
    public static func spec(_ id: String) -> CommandSpec<HaloMenuState> {
        specs[id] ?? .typed(id, title: id, summary: "Halo has no \(id) command.", kind: .view, params: JSONValue.self,
                            example: .object([:]), availability: { _ in .unavailable("Halo has no \(id) command.") }) { _, _ in JSONValue.object([:]) }
    }

    static let specs = Dictionary(uniqueKeysWithValues: HaloProject.commandSpecs.map { spec in
        (spec.id, CommandSpec<HaloMenuState>.typed(
            spec.id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: spec.params,
            result: spec.result, example: spec.example, availability: { $0.availability(spec.id) }) { state, params in
            guard var project = state.project else { throw CatalogError.unavailable(id: spec.id, why: noWindow) }
            let result = try HaloProject.catalog.run(spec.id, params: params, on: &project).result
            state.project = project
            return result
        })
    })

    /// Whether the menu item for `id` can run, and why not.
    public func availability(_ id: String) -> Availability {
        guard let project else { return .unavailable(Self.noWindow) }
        return HaloProject.catalog.availability(id, on: project)
    }

    /// The item's title for `command`: Undo and Redo name their step.
    public func title(_ command: HaloCommand) -> String { project?.title(for: command) ?? command.title }
}
