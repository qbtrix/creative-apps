// Live/LiveAdjustmentLayers.swift: the live adjustment layers. PV-6 replaces
// this NotBuilt stand-in. Linux-safe.
enum LiveAdjustmentLayers { static func make() -> any AdjustmentLayering { NotBuiltAdjustmentLayers() } }
