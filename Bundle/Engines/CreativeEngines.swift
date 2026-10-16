// CreativeEngines.swift: the one shared engine framework of AfterGlow.app
// (route R1, docs/blueprints/suite.md 2.5). project.yml's CreativeEngines
// target compiles only this file and is the only Release target that links
// the creative-core products, so FlareCore, CoreRaster and CoreColor are
// linked once, into CreativeEngines.framework, instead of into each app
// executable. Each <X>Model links this framework and keeps its own
// `import FlareCore` (and the rest), which resolves through these
// re-exports. SwiftPM never compiles this file: Package.swift's Linux and
// test graph links the engines into each Model directly.
@_exported import CoreColor
@_exported import CoreRaster
@_exported import FlareCore
