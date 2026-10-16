// FakeRouting.swift: the reference DocumentRouting (UC-4), pure. A file goes
// to its type's default app; anything else is `unsupportedFile`. Its refusal
// is the answer, not an outage: the routing slot returns this reference fake
// (packet correction 6), so it takes no `unavailable:`.

public struct FakeRouting: DocumentRouting {
    public var registry: SuiteTypeRegistry
    public init(registry: SuiteTypeRegistry = .standard) { self.registry = registry }

    public func route(fileName: String) throws(SuiteError) -> SuiteApp {
        if fileName.hasSuffix(".aghandoff") { return .launcher }
        let ext = fileName.split(separator: ".").last.map(String.init) ?? ""
        guard fileName.contains("."), let t = registry.type(forExtension: ext), let app = registry.defaultApp(for: t.id) else {
            throw .unsupportedFile(name: fileName)
        }
        return app
    }

    public func openInTargets(for type: SuiteTypeID, from app: SuiteApp) -> [SuiteApp] {
        (registry.type(type)?.readers ?? []).filter { $0 != app }
    }

    public func openInRefusal(for type: SuiteTypeID, from app: SuiteApp) -> SuiteError? {
        openInTargets(for: type, from: app).isEmpty ? .noOtherReader(typeName: registry.type(type)?.name ?? "these") : nil
    }
}
