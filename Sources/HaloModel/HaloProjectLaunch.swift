// HaloProjectLaunch.swift: the one public way to start a project on a given
// document, which HaloApp's HaloLaunch uses for `-HaloFixture` and
// `-HaloSample`. It goes through `restore`, so the project opens with no undo
// steps, nothing unsaved and no refusal. Linux-safe: no UI imports.

extension HaloProject {
    /// A project on `services` that opens holding `document`, with an empty
    /// history and nothing unsaved.
    public init(services: HaloServices, document: HaloDocumentState) {
        self.init(services: services)
        restore(document)
    }
}
