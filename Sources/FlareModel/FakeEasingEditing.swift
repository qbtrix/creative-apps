// FakeEasingEditing.swift: a deterministic, in-memory EasingEditing for the
// easing editor's UI track and its snapshots, so views can be built before
// FlareWorkspace conforms. It holds four fixed segments and keeps the
// contract's invariants (see EasingEditing.swift) with its own undo stack.
// Not wired into any window; the real editor runs on FlareWorkspace.
import FlareCore

public struct FakeEasingEditing: EasingEditing, Equatable {
    private struct Change: Equatable, Sendable {
        let segment: EasingSegment
        let easing: Easing
    }

    public let easingSegments: [EasingSegment]
    public private(set) var selectedEasingSegment: EasingSegment?
    public let easingUnavailableReason: String?
    private var easings: [EasingSegment: Easing]
    private var history: [Change] = []
    /// The handle being dragged; moves of it fold into one undo step.
    private var dragging: EasingHandle?

    /// x 0-24 Ease (selected), x 24-48 Linear, y 0-24 Hold, opacity 12-36
    /// Ease In-Out. With `unavailableReason`, every edit is refused.
    public init(unavailableReason: String? = nil) {
        easingUnavailableReason = unavailableReason
        let fixture: [(EasingSegment, Easing)] = [
            (EasingSegment(property: "opacity", startFrame: 12, endFrame: 36), .easeInOut),
            (EasingSegment(property: "x", startFrame: 0, endFrame: 24), .ease),
            (EasingSegment(property: "x", startFrame: 24, endFrame: 48), .linear),
            (EasingSegment(property: "y", startFrame: 0, endFrame: 24), .hold),
        ]
        easingSegments = fixture.map(\.0)
        easings = Dictionary(uniqueKeysWithValues: fixture)
        selectedEasingSegment = fixture[1].0
    }

    public var currentEasing: Easing? { selectedEasingSegment.flatMap { easings[$0] } }
    public var canUndo: Bool { !history.isEmpty }

    public mutating func selectEasingSegment(_ segment: EasingSegment) {
        guard easings[segment] != nil else { return }
        selectedEasingSegment = segment
        dragging = nil
    }

    public mutating func setEasingPreset(_ preset: EasingPreset) {
        dragging = nil
        set(preset.easing)
    }

    public mutating func moveEasingHandle(_ handle: EasingHandle, to point: Point) {
        guard easingUnavailableReason == nil, let easing = currentEasing, let next = EasingCurve.moving(easing, handle, to: point) else { return }
        if dragging == handle, let segment = selectedEasingSegment {
            easings[segment] = next
        } else {
            dragging = handle
            set(next)
        }
    }

    public mutating func endEasingHandleDrag() { dragging = nil }

    public func easingCurveSamples(count: Int) -> [Point] {
        currentEasing.map { EasingCurve.samples(of: $0, count: count) } ?? []
    }

    public mutating func undo() {
        dragging = nil
        guard let change = history.popLast() else { return }
        easings[change.segment] = change.easing
    }

    /// Records the selected segment's easing for undo, then replaces it.
    private mutating func set(_ easing: Easing) {
        guard easingUnavailableReason == nil, let segment = selectedEasingSegment, let old = easings[segment]
        else { return }
        history.append(Change(segment: segment, easing: old))
        easings[segment] = easing
    }
}
