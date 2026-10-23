// VectorStroke.swift (stroke-style SS-1, complete): the suite's stroke is FlareCore's, under a kernel name, so Flare's
// stored strokes, every exporter and every app Model share one stroke model (contract rule 20). The name is
// `VectorStroke`, never `Stroke`: `SuiteKernel/Stroke/` is the brush module and SwiftUI owns `StrokeStyle`.
import FlareCore

/// A shape's outline: FlareCore's `Stroke` (colour, width, join, cap; dash, dash phase and trim after the core bump).
public typealias VectorStroke = FlareCore.Stroke

/// How a stroke's corners meet: FlareCore's `Stroke.Join` (miter, round, bevel).
public typealias StrokeJoin = FlareCore.Stroke.Join

/// How a stroke's open ends finish: FlareCore's `Stroke.Cap` (butt, round, square).
public typealias StrokeCap = FlareCore.Stroke.Cap

/// The dash patterns the editor offers; `StrokeRules.pattern` scales each by the stroke's width.
public enum DashPreset: String, Codable, CaseIterable, Sendable { case solid, dashed, dotted, custom }
