// Live/LiveCrop.swift: the live crop sizing. PV-3 replaces this NotBuilt
// stand-in. Linux-safe.
enum LiveCrop { static func make() -> any CropSizing { NotBuiltCrop() } }
