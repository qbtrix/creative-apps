// Live/LiveDocuments.swift: the live document use cases. PV-1
// (photo-documents) replaces these NotBuilt stand-ins with the real archive
// and recovery store. Linux-safe.
enum LiveDocuments {
    static func archive() -> any DocumentArchiving { NotBuiltArchive() }
    static func recovery() -> any RecoveryStoring { NotBuiltRecovery() }
}
