// Live/LiveClipboard.swift: Cut, Copy and Paste on the live services. Until the
// clipboard feature takes this file over, the pasteboard type, every help and
// every write forward to NotBuilt("Copy and paste"), so the commands are
// disabled with "Copy and paste isn't built yet." and never act. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct LiveClipboard: LayerClipboard {
    private let base = NotBuilt("Copy and paste")
    public init() {}

    public var pasteboardType: String { base.pasteboardType }
    public func copyHelp(_ ids: [String], on page: DesignPage) -> String? { base.copyHelp(ids, on: page) }
    public func encode(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> Data { try base.encode(ids, on: page) }
    public func pasteHelp(_ data: Data?) -> String? { base.pasteHelp(data) }
    public func paste(_ data: Data, into parentID: String?, on page: DesignPage,
                      mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        try base.paste(data, into: parentID, on: page, mint: &mint)
    }
}
