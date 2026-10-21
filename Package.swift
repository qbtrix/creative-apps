// swift-tools-version: 6.0
// creative-apps: the macOS app shells of the creative suite. Every target the
// suite needs is declared here, so feature work never edits this file.
//
//   <X>Model  Linux-safe view-model state and logic, Foundation only, calls
//             the creative-core engines. Built and tested on Linux and macOS.
//   <X>App    the SwiftUI app: a window built only from SuiteUI. macOS only.
//   SuiteUI   the shared design system (tokens, Liquid Glass primitives,
//             the window shell, the app marks; links SuiteModel for the app
//             list). macOS only.
// for X in Flare (2D animation), Design (vector and UI design), Photo (raster
// editing), Library (photo catalog) and Halo (motion graphics).
//
//   SuiteModel  the suite's shared Linux-safe values (identity, the app list;
//             docs/blueprints/suite.md), Foundation only, linked by every
//             <X>Model. With SuiteModelTests, on Linux and macOS.
//   SuiteKernel  the editor kernel: one Linux-safe library, one module per
//             editor concept the apps used to build five times (history,
//             selection, layer tree, keys and easing, snap, transform, export,
//             session, stroke), Foundation and FlareCore only (it imports
//             FlareCore's Point, Rect, Matrix, Keyframe and Easing as they
//             are), linked by every <X>Model and by SuiteUI
//             (docs/blueprints/suiteui/features/editor-kernel.md). With
//             SuiteKernelTests, on Linux and macOS.
//   SuiteShell  macOS glue every app process links: the shared menu commands
//             (Window > Switch To) and, later, the live suite services.
//             macOS only.
//   AfterGlowApp  the launcher: the home window that opens the five apps.
//             macOS only.
//
//   AfterGlowCLICore, AfterGlowCLI  the `afterglow` command line tool: the
//             Linux-safe router library (Foundation, SuiteKernel, SuiteModel
//             and every <X>Model) and its thin executable, product
//             "afterglow". With AfterGlowCLITests, on Linux and macOS
//             (docs/blueprints/suite/features/afterglow-cli.md). Headless, so
//             not part of the Release graph in project.yml.
//
//   AppAuditTests  the app audit's pure code (pixel math, engine, checks) and
//             its tests, Foundation only, on Linux and macOS. project.yml
//             also compiles its non-test files into every UI journey bundle
//             (docs/blueprints/app-audit.md).
//
// The macOS-only targets are appended under `#if os(macOS)`. The manifest is
// evaluated on the host, so on Linux they do not exist at all: `swift build`
// and `swift test` there cover exactly the Model targets (SuiteModel and
// SuiteKernel among them), the afterglow CLI and their tests.
import PackageDescription

// The engines, pinned to one creative-core commit (`revision:` below; core has
// no tags yet), so a core merge reaches the apps only through a bump PR.
// Package.resolved is committed and records the same commit. scripts/bump-core
// moves the pin: it edits the revision, resolves, runs the Model tests and the
// brush perf suites, and opens "chore(core): bump creative-core to <sha>".
let core = "creative-core"

func model(_ name: String, _ engines: [String]) -> [Target] {
    [
        .target(
            name: "\(name)Model",
            dependencies: ["SuiteModel", "SuiteKernel"] + engines.map { .product(name: $0, package: core) }
        ),
        .testTarget(name: "\(name)ModelTests", dependencies: [.target(name: "\(name)Model")]),
    ]
}

let apps = ["Flare", "Design", "Photo", "Library", "Halo"]

var products: [Product] = [.executable(name: "afterglow", targets: ["AfterGlowCLI"])]
var targets: [Target] =
    model("Flare", ["FlareCore"])
    + model("Design", ["CoreColor"])
    + model("Photo", ["CoreRaster", "CoreColor", "CoreRender"])
    + model("Library", ["CoreRaster", "CoreColor"])
    + model("Halo", ["FlareCore", "CoreRaster"])
    + [
        .target(name: "SuiteModel"),
        .testTarget(name: "SuiteModelTests", dependencies: ["SuiteModel"]),
        .target(name: "SuiteKernel", dependencies: [.product(name: "FlareCore", package: core)]),
        .testTarget(name: "SuiteKernelTests", dependencies: ["SuiteKernel"]),
        .testTarget(name: "AppAuditTests"),
        .target(name: "AfterGlowCLICore", dependencies: ["SuiteKernel", "SuiteModel"] + apps.map { .target(name: "\($0)Model") }),
        .executableTarget(name: "AfterGlowCLI", dependencies: ["AfterGlowCLICore"]),
        .testTarget(name: "AfterGlowCLITests", dependencies: ["AfterGlowCLICore"]),
    ]

#if os(macOS)
products += (apps + ["AfterGlow"]).map { .executable(name: "\($0)App", targets: ["\($0)App"]) }
targets += [
    .target(name: "SuiteUI", dependencies: ["SuiteModel", "SuiteKernel"]),
    .target(name: "SuiteShell", dependencies: ["SuiteUI", "SuiteModel"]),
    .executableTarget(name: "AfterGlowApp", dependencies: ["SuiteUI", "SuiteShell", "SuiteModel"]),
    .testTarget(name: "SuiteUITests", dependencies: ["SuiteUI", "SuiteModel"]),
    .testTarget(
        name: "AppSnapshotTests",
        dependencies: ["SuiteUI", "AfterGlowApp", "SuiteShell", "SuiteModel", .product(name: "CoreRenderMetal", package: core)]
            + apps.flatMap { [.target(name: "\($0)App"), .target(name: "\($0)Model")] }
    ),
]
// Photo draws its canvas through CoreRender's dispatcher, on the Metal backend when the View > Rendering choice allows.
let appEngines: [String: [Target.Dependency]] = ["Photo": [.product(name: "CoreRenderMetal", package: core)]]
targets += apps.map {
    .executableTarget(name: "\($0)App",
                      dependencies: ["SuiteUI", "SuiteShell", .target(name: "\($0)Model")] + appEngines[$0, default: []])
}
#endif

let package = Package(
    name: "creative-apps",
    // macOS 26 for Liquid Glass. Ignored on Linux. The string form works with
    // tools 6.0, where the `.v26` case does not exist yet.
    platforms: [.macOS("26.0")],
    products: products,
    dependencies: [
        .package(url: "https://github.com/qbtrix/creative-core", revision: "7966e5a990ce887bbced25b58ee1134a5b170435"),
    ],
    targets: targets
)
