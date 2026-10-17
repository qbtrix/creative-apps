// SuiteKernel.swift: the editor kernel's header. SuiteKernel is one
// Linux-safe library every app Model and SuiteUI link, with one module per
// editor concept the five apps used to build each on their own
// (docs/blueprints/suiteui/features/editor-kernel.md; the design's inventory
// counted every copy). The modules, one folder each under Sources/SuiteKernel:
//
//   History/    named undo steps, coalescing runs, a drag as one step, step ids
//               that never repeat, dirty read exactly as saved-vs-current
//   Selection/  an ordered selection with a primary and an anchor, one `Pick`
//               (replace, toggle, extend), the nudge and marquee rules
//   Layers/     the layer tree: nesting, order, hide and lock cascades, a
//               follow link (parenting on day one, bones later)
//   Keys/       key and easing rules over FlareCore's `Keyframe` and `Easing`
//   Snap/       the snap contract: candidates and the order of offsets
//   Transform/  box resize math by handle and handle hit testing
//   Export/     the export run's states and progress
//   Session/    the document session (dirty, save status, autosave, recovery)
//               and versioned JSON probing
//   Stroke/     pressure samples, smoothing, dab spacing, brush settings and
//               presets, the live copy a drag draws on
//
// Geometry.swift gives the kernel its geometry: FlareCore's `Point`, `Rect`
// and `Matrix` under kernel names, the handle, pick, direction and modifier
// enums every module shares.
//
// The rule: no app copies a kernel concept. A Model that needs history,
// selection, a layer tree or any module above imports SuiteKernel and
// conforms or adapts; it never re-implements the concept (docs/factory/lead.md
// rule 20, scripts/check-dup-logic). A missing kernel behaviour is a task in
// the editor-kernel packet or a `gap` issue on `line:suiteui`, never a copy.
//
// Linux-safe: Foundation (as FoundationEssentials where it exists) and
// FlareCore only. No SwiftUI, AppKit, Combine or CoreGraphics; no app Model,
// no SuiteUI, no SuiteModel (`KernelShapeTests.importsOnlyFoundationAndFlareCore`
// scans for that). Swift 6 language mode, value types, `Sendable`. Every file
// here imports Foundation as
//
//   #if canImport(FoundationEssentials)
//   import FoundationEssentials
//   #else
//   import Foundation
//   #endif
//
// so the Linux build takes the small Foundation and macOS the full one.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The kernel's shape: its version, so a Model or a test can state which
/// kernel shape it was written against. Not named `SuiteKernel`: a type that
/// shares its module's name shadows the module, and `SuiteKernel.Point` must
/// keep naming the module's alias.
public enum KernelShape {
    /// The kernel's shape version. 1 is the contract slice (EK-a): the
    /// geometry and every module's declared signatures. It moves only when a
    /// public signature changes shape, never when a stub gains its body.
    public static let version = 1
}
