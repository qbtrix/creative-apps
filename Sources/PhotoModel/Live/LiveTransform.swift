// Live/LiveTransform.swift: the live layer transform. PV-7 replaces this
// NotBuilt stand-in. Linux-safe.
enum LiveTransform { static func make() -> any LayerTransforming { NotBuiltTransform() } }
