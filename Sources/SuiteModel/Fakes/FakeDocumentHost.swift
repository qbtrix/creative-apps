// FakeDocumentHost.swift: a SuiteDocumentHost (UC-18) that records what it
// was asked to do and refuses the verbs it doesn't take. With `unavailable:`
// set, it refuses everything and `accept` throws `.notAvailable(that sentence)`.

public actor FakeDocumentHost: SuiteDocumentHost {
    public let app: SuiteApp
    public let verbs: Set<HandOffVerb>
    public private(set) var accepted: [HandOff] = []
    let unavailable: String?
    public init(app: SuiteApp, verbs: Set<HandOffVerb>, unavailable: String? = nil) {
        self.app = app; self.verbs = verbs; self.unavailable = unavailable
    }
    public func refusal(for handOff: HandOff) -> SuiteError? {
        if let unavailable { return .notAvailable(unavailable) }
        return verbs.contains(handOff.verb) ? nil : .notAvailable("\(app.displayName) can't do that yet.")
    }
    public func accept(_ handOff: HandOff) throws(SuiteError) -> HandOffState {
        if let r = refusal(for: handOff) { throw r }
        accepted.append(handOff)
        return handOff.verb == .edit ? .accepted : .returned
    }
}
