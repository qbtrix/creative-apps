// Live/LiveDocuments.swift: the live document use cases. PV-1
// (photo-documents) fills these: the archive is LiveArchive, the OpenRaster
// document; the recovery store is still the NotBuilt stand-in until D-4b.
// Linux-safe.
enum LiveDocuments {
    static func archive() -> any DocumentArchiving { LiveArchive() }
    static func recovery() -> any RecoveryStoring { NotBuiltRecovery() }
}
