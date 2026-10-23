// DesignPasteboardAdapter.swift: clipboard-interop CB-6 stub; the next commit builds it. Linux-safe.
import SuiteModel

public struct DesignPasteboardAdapter {
    public init() {}

    public func copy(_ workspace: DesignWorkspace) throws -> [TypedData] { [] }

    public func paste(_ item: SuiteClipItem, into workspace: inout DesignWorkspace, centredOn centre: DesignPoint?) throws {}
}
