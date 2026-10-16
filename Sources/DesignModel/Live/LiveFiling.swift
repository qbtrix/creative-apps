// Live/LiveFiling.swift: Open, Save and Save As on the live services, wrapping
// today's codec in DesignFile. `encode` writes the document's pages the way
// `fileData()` does, so saving through it gives today's bytes, and `decode`
// reads a file the way `open(_:at:)` does, all or nothing, so a refused file
// throws DesignFile's error (and its reason) and nothing is opened. Components
// and variables are not in the file until wave 2 (D2-1). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct LiveFiling: DocumentFiling {
    public init() {}

    public func encode(_ document: DesignDocument) throws(DesignFileError) -> Data {
        var workspace = DesignWorkspace()
        workspace.load(document.pages)
        return try workspace.fileData()
    }

    public func decode(_ data: Data) throws(DesignFileError) -> DesignDocument {
        var workspace = DesignWorkspace()
        try workspace.open(data)
        return DesignDocument(pages: workspace.pages)
    }
}
