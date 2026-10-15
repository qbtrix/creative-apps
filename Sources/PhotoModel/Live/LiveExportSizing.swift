// Live/LiveExportSizing.swift: the live export sizing. PV-8 replaces this
// NotBuilt stand-in. Linux-safe.
enum LiveExportSizing { static func make() -> any ExportSizing { NotBuiltExportSizing() } }
