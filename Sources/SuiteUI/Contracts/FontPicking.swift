// FontPicking.swift: what the font picker reports (packet
// docs/blueprints/suiteui/features/font-picker.md, Contract slice; FP-1).
// A pick is a family by name, one of its faces and a size in points; the
// picker hands one to its `onPick` closure and never reads a Model or a
// service. Foundation free, Sendable.
import SuiteModel

/// One font picker choice: a family, one of its faces, and a size in points.
public struct FontPick: Hashable, Sendable {
    public var family: String
    public var face: FontFace
    public var size: Double

    public init(family: String, face: FontFace, size: Double) {
        self.family = family
        self.face = face
        self.size = size
    }
}
