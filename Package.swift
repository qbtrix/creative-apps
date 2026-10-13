// swift-tools-version: 6.0
// creative-apps: the macOS app shells of the creative suite. Every target the
// suite needs is declared here, so feature work never edits this file.
//
//   <X>Model  Linux-safe view-model state and logic, Foundation only, calls
//             the creative-core engines. Built and tested on Linux and macOS.
//   <X>App    the SwiftUI app: a window built only from SuiteUI. macOS only.
//   SuiteUI   the shared design system (tokens, Liquid Glass primitives,
//             the window shell). macOS only.
// for X in Flare (2D animation), Design (vector and UI design), Photo (raster
// editing), Library (photo catalog) and Halo (motion graphics).
//
//   AppAuditTests  the app audit's pure code (pixel math, engine, checks) and
//             its tests, Foundation only, on Linux and macOS. project.yml
//             also compiles its non-test files into every UI journey bundle
//             (docs/blueprints/app-audit.md).
//
// The macOS-only targets are appended under `#if os(macOS)`. The manifest is
// evaluated on the host, so on Linux they do not exist at all: `swift build`
// and `swift test` there cover exactly the Model targets and their tests.
import PackageDescription

// The engines. Tracks creative-core's main branch for now; this moves to a
// pinned version (`exact:`) once creative-core tags releases. Package.resolved
// is not committed, so every build resolves the current main.
let core = "creative-core"

func model(_ name: String, _ engines: [String]) -> [Target] {
    [
        .target(name: "\(name)Model", dependencies: engines.map { .product(name: $0, package: core) }),
        .testTarget(name: "\(name)ModelTests", dependencies: [.target(name: "\(name)Model")]),
    ]
}

let apps = ["Flare", "Design", "Photo", "Library", "Halo"]

var products: [Product] = []
var targets: [Target] =
    model("Flare", ["FlareCore"])
    + model("Design", ["CoreColor"])
    + model("Photo", ["CoreRaster", "CoreColor"])
    + model("Library", ["CoreRaster", "CoreColor"])
    + model("Halo", ["FlareCore", "CoreRaster"])
    + [.testTarget(name: "AppAuditTests")]

#if os(macOS)
products += apps.map { .executable(name: "\($0)App", targets: ["\($0)App"]) }
targets += [
    .target(name: "SuiteUI"),
    .testTarget(name: "SuiteUITests", dependencies: ["SuiteUI"]),
    .testTarget(
        name: "AppSnapshotTests",
        dependencies: ["SuiteUI"] + apps.flatMap { [.target(name: "\($0)App"), .target(name: "\($0)Model")] }
    ),
]
targets += apps.map { .executableTarget(name: "\($0)App", dependencies: ["SuiteUI", .target(name: "\($0)Model")]) }
#endif

let package = Package(
    name: "creative-apps",
    // macOS 26 for Liquid Glass. Ignored on Linux. The string form works with
    // tools 6.0, where the `.v26` case does not exist yet.
    platforms: [.macOS("26.0")],
    products: products,
    dependencies: [
        .package(url: "https://github.com/qbtrix/creative-core", branch: "main"),
    ],
    targets: targets
)
