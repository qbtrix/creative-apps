// Live/LiveTransform.swift: the live layer transform, on SuiteKernel
// (LiveTransform+Kernel.swift); applying it to pixels is still PV-7's.
// Linux-safe.
enum LiveTransform { static func make() -> any LayerTransforming { KernelTransform() } }
