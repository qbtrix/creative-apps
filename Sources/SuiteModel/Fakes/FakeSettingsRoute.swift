// FakeSettingsRoute.swift: the in-memory SettingsRouting (UC-12); records
// each pane it was asked to open. With `unavailable:` set, `open` throws
// `.notAvailable(that sentence)` and records nothing.

public actor FakeSettingsRoute: SettingsRouting {
    public private(set) var opened: [SettingsPane] = []
    let unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }
    public func open(_ pane: SettingsPane, from app: SuiteApp) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        opened.append(pane)
    }
}
