// Live/LiveDocuments.swift: the live document use cases. PV-1
// (photo-documents) fills these: the archive is LiveArchive, the OpenRaster
// document; the recovery store is LiveRecovery, one autosave file per window
// in a folder (~/Library/Application Support/Photo/Recovery unless the window
// names another). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

enum LiveDocuments {
    static func archive() -> any DocumentArchiving { LiveArchive() }
    static func recovery() -> any RecoveryStoring { LiveRecovery(directory: LiveRecovery.defaultDirectory) }
    static func recovery(directory: URL) -> any RecoveryStoring { LiveRecovery(directory: directory) }
}
