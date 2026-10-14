#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: 5.1 Shared value types (Contracts/ContractTypes.swift)

/// A point in points (view space) or document pixels; the call says which.
public struct PlanePoint: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// A width and height. Not called "Size": `SuiteSize` is the size token enum.
public struct PlaneExtent: Hashable, Sendable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
}

public struct PlaneRect: Hashable, Sendable {
    public var origin: PlanePoint
    public var extent: PlaneExtent
    public init(x: Double, y: Double, width: Double, height: Double) {
        origin = PlanePoint(x: x, y: y); extent = PlaneExtent(width: width, height: height)
    }
    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + extent.width }
    public var maxY: Double { origin.y + extent.height }
    public var mid: PlanePoint { PlanePoint(x: origin.x + extent.width / 2, y: origin.y + extent.height / 2) }
    public func contains(_ p: PlanePoint) -> Bool { p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY }
}

public struct KeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let shift = KeyModifiers(rawValue: 1)    // coarse ×10, constrain, extend
    public static let option = KeyModifiers(rawValue: 2)   // fine ×0.1
    public static let command = KeyModifiers(rawValue: 4)  // toggle in a selection
}

public enum GridArrow: Sendable, CaseIterable { case left, right, up, down }

/// One gesture, one end. Every component that reports `onEnd` keeps one of
/// these: a drag, a typed commit, a key press or a nudge opens a run with its
/// first change and closes it once, so the host makes it one undo step.
public struct EditRun: Equatable, Sendable {
    public private(set) var isOpen = false
    public private(set) var ends = 0
    public init() {}
    /// Returns true when this change opened the run.
    public mutating func change() -> Bool {
        defer { isOpen = true }
        return !isOpen
    }
    /// Returns true exactly once per opened run; an end with no change is ignored.
    public mutating func end() -> Bool {
        guard isOpen else { return false }
        isOpen = false; ends += 1
        return true
    }
}

// MARK: 5.2 Use-case protocols, one per use case, each with its Fake

// UC1 · SJ11, SJ12, SP1 · Contracts/ValueScrubbing.swift
public struct ScrubSpec: Hashable, Sendable {
    public var range: ClosedRange<Double>
    public var step: Double
    public var decimals: Int
    public var unit: String
    public init(range: ClosedRange<Double>, step: Double, decimals: Int = 2, unit: String = "") {
        self.range = range; self.step = step; self.decimals = decimals; self.unit = unit
    }
}

/// A non-linear track (Photo's log gamma): the bar moves in positions, the
/// field shows values; `stepped` is #591's track-owned discrete step.
public protocol TrackStepping: Sendable {
    func position(of value: Double) -> Double
    func value(at position: Double) -> Double
    func stepped(_ position: Double, by direction: Double) -> Double
}

public protocol ValueScrubbing: Sendable {
    /// Press-and-drag scrubs relative to `start`: one step per point, ⇧ ×10, ⌥ ×0.1; clamped and snapped.
    func dragged(from start: Double, by points: Double, modifiers: KeyModifiers, spec: ScrubSpec) -> Double
    /// Arrows step (⇧ coarse, ⌥ fine), Home and End jump to the ends; on a track the track steps.
    func pressed(_ key: ScrubKey, from value: Double, modifiers: KeyModifiers, spec: ScrubSpec,
                 track: (any TrackStepping)?) -> Double
    /// The typed text when the field closes. Text that isn't a number keeps `old`.
    func committed(_ text: String, opening: String, old: Double, spec: ScrubSpec) -> Double
    /// How far the bar's fill reaches, 0...1.
    func fraction(_ value: Double, spec: ScrubSpec) -> Double
    /// What the row shows ("45°") and what VoiceOver reads ("45 degrees").
    func text(_ value: Double, spec: ScrubSpec) -> String
    func spoken(_ value: Double, spec: ScrubSpec) -> String
}

/// Linear and unsnapped, two decimals: enough to build and snapshot a row before the live rules are wired.
public struct FakeValueScrubbing: ValueScrubbing {
    public init() {}
    private func clamp(_ v: Double, _ r: ClosedRange<Double>) -> Double { v.isFinite ? min(max(v, r.lowerBound), r.upperBound) : r.lowerBound }
    private func mult(_ m: KeyModifiers) -> Double { m.contains(.option) ? 0.1 : m.contains(.shift) ? 10 : 1 }
    public func dragged(from start: Double, by points: Double, modifiers: KeyModifiers, spec: ScrubSpec) -> Double {
        clamp(start + points * spec.step * mult(modifiers), spec.range)
    }
    public func pressed(_ key: ScrubKey, from value: Double, modifiers: KeyModifiers, spec: ScrubSpec,
                        track: (any TrackStepping)?) -> Double {
        switch key {
        case .home: return spec.range.lowerBound
        case .end: return spec.range.upperBound
        case .increment, .decrement:
            let direction: Double = key == .increment ? 1 : -1
            if let track { return clamp(track.value(at: track.stepped(track.position(of: value), by: direction)), spec.range) }
            return clamp(value + direction * spec.step * mult(modifiers), spec.range)
        }
    }
    public func committed(_ text: String, opening: String, old: Double, spec: ScrubSpec) -> Double {
        Double(String(text.filter { $0 != " " })).map { clamp($0, spec.range) } ?? old
    }
    public func fraction(_ value: Double, spec: ScrubSpec) -> Double {
        let span = spec.range.upperBound - spec.range.lowerBound
        return span > 0 ? clamp((value - spec.range.lowerBound) / span, 0...1) : 0
    }
    public func text(_ value: Double, spec: ScrubSpec) -> String { "\(value)\(spec.unit)" }
    public func spoken(_ value: Double, spec: ScrubSpec) -> String { spec.unit.isEmpty ? "\(value)" : "\(value) \(spec.unit)" }
}

// UC2 · SJ12 · Contracts/HexColorEditing.swift
public struct RGB8: Hashable, Sendable {
    public var red: UInt8, green: UInt8, blue: UInt8
    public init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) { self.red = red; self.green = green; self.blue = blue }
}

public protocol HexColorEditing: Sendable {
    /// "#RRGGBB", "RRGGBB" or "#RGB" in either case; nil otherwise.
    func parse(_ text: String) -> RGB8?
    /// The color after the hex field closes: the parsed color, or `old` for text that isn't one.
    func committed(_ text: String, old: RGB8) -> RGB8
    /// Always "#RRGGBB", upper case.
    func format(_ color: RGB8) -> String
}

/// Accepts six hex digits only (no "#RGB" shorthand).
public struct FakeHexColorEditing: HexColorEditing {
    public init() {}
    public func parse(_ text: String) -> RGB8? {
        let digits = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard digits.count == 6, let v = UInt32(digits, radix: 16) else { return nil }
        return RGB8(UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF))
    }
    public func committed(_ text: String, old: RGB8) -> RGB8 { parse(text) ?? old }
    public func format(_ c: RGB8) -> String {
        let hex = [c.red, c.green, c.blue].map { b -> String in
            let s = String(b, radix: 16, uppercase: true); return s.count == 1 ? "0" + s : s
        }
        return "#" + hex.joined()
    }
}

// UC3 · SJ14 · Contracts/KeyframeFacing.swift
public enum KeyPresence: Sendable, CaseIterable { case idle, animated, keyedHere }
public enum KeyAction: Sendable { case add, remove }

public struct KeyframeFace: Hashable, Sendable {
    public var symbol: String
    public var diamondSymbol: String?       // nil: the slot is reserved but empty
    public var diamondAction: KeyAction?
    public var spoken: String
    public init(symbol: String, diamondSymbol: String?, diamondAction: KeyAction?, spoken: String) {
        self.symbol = symbol; self.diamondSymbol = diamondSymbol; self.diamondAction = diamondAction; self.spoken = spoken
    }
}

public protocol KeyframeFacing: Sendable {
    func face(for presence: KeyPresence) -> KeyframeFace
}

public struct FakeKeyframeFacing: KeyframeFacing {
    public init() {}
    public func face(for presence: KeyPresence) -> KeyframeFace {
        switch presence {
        case .idle: KeyframeFace(symbol: "stopwatch", diamondSymbol: nil, diamondAction: nil, spoken: "Not animated")
        case .animated: KeyframeFace(symbol: "stopwatch.fill", diamondSymbol: "diamond", diamondAction: .add, spoken: "Animated")
        case .keyedHere: KeyframeFace(symbol: "stopwatch.fill", diamondSymbol: "diamond.fill", diamondAction: .remove, spoken: "Keyed at this frame")
        }
    }
}

// UC4 · SJ15 · Contracts/PresetNavigating.swift
public protocol PresetNavigating: Sendable {
    /// The preset an arrow key moves focus to in a grid of `count` presets in `columns` columns; nil at an edge.
    func neighbor(of index: Int, _ arrow: GridArrow, count: Int, columns: Int) -> Int?
}

/// Wraps instead of stopping at the edges (the live rule stops), so a UI built on it must not rely on wrapping.
public struct FakePresetNavigating: PresetNavigating {
    public init() {}
    public func neighbor(of index: Int, _ arrow: GridArrow, count: Int, columns: Int) -> Int? {
        guard count > 0, columns > 0, (0..<count).contains(index) else { return nil }
        let delta = switch arrow { case .left: -1; case .right: 1; case .up: -columns; case .down: columns }
        return ((index + delta) % count + count) % count
    }
}

// UC5 · SJ1, SJ2 · Contracts/ShellLayingOut.swift
public struct ShellMetrics: Hashable, Sendable {
    public var leadingWidth: Double          // the rail (EditorShell) or the sidebar's ideal (SuiteWindow)
    public var trailingWidth: Double         // the right panel or the inspector's ideal
    public var contentMinimum: PlaneExtent
    public var slotMinimum: Double           // the timeline slot when open
    public var slotToolbar: Double           // what stays when collapsed
    public init(leadingWidth: Double, trailingWidth: Double, contentMinimum: PlaneExtent,
                slotMinimum: Double, slotToolbar: Double) {
        self.leadingWidth = leadingWidth; self.trailingWidth = trailingWidth; self.contentMinimum = contentMinimum
        self.slotMinimum = slotMinimum; self.slotToolbar = slotToolbar
    }
}

public struct ShellColumns: Hashable, Sendable {
    public var leading: Double, content: Double, trailing: Double
    /// False when the window is narrower than the three columns' minimum (the window minimum prevents it).
    public var fits: Bool
    public init(leading: Double, content: Double, trailing: Double, fits: Bool) {
        self.leading = leading; self.content = content; self.trailing = trailing; self.fits = fits
    }
}

public struct TimelineSlot: Hashable, Sendable {
    public var height: Double
    public var collapsed: Bool
    public var lastOpenHeight: Double
    public init(height: Double, collapsed: Bool = false, lastOpenHeight: Double? = nil) {
        self.height = height; self.collapsed = collapsed; self.lastOpenHeight = lastOpenHeight ?? height
    }
}

public protocol ShellLayingOut: Sendable {
    /// Leading and trailing columns keep their widths; the content takes the rest, never below its minimum.
    func columns(windowWidth: Double, metrics: ShellMetrics) -> ShellColumns
    /// A divider drag of `dy` points (up is negative), clamped so the canvas keeps its minimum height.
    func slot(_ slot: TimelineSlot, dragged dy: Double, available height: Double, metrics: ShellMetrics) -> TimelineSlot
    /// Collapse to the toolbar row, or restore the last open height.
    func toggled(_ slot: TimelineSlot, metrics: ShellMetrics) -> TimelineSlot
}

/// No clamping on the slot: fine for building the divider's look, wrong for SJ2's limits.
public struct FakeShellLayingOut: ShellLayingOut {
    public init() {}
    public func columns(windowWidth: Double, metrics: ShellMetrics) -> ShellColumns {
        let content = windowWidth - metrics.leadingWidth - metrics.trailingWidth
        return ShellColumns(leading: metrics.leadingWidth, content: max(content, metrics.contentMinimum.width),
                            trailing: metrics.trailingWidth, fits: content >= metrics.contentMinimum.width)
    }
    public func slot(_ slot: TimelineSlot, dragged dy: Double, available height: Double, metrics: ShellMetrics) -> TimelineSlot {
        let h = slot.height - dy
        return TimelineSlot(height: h, collapsed: false, lastOpenHeight: h)
    }
    public func toggled(_ slot: TimelineSlot, metrics: ShellMetrics) -> TimelineSlot {
        slot.collapsed ? TimelineSlot(height: slot.lastOpenHeight, collapsed: false, lastOpenHeight: slot.lastOpenHeight)
                       : TimelineSlot(height: metrics.slotToolbar, collapsed: true, lastOpenHeight: slot.height)
    }
}

// UC6 · SJ4 · Contracts/ToolPicking.swift
public struct ToolFace: Hashable, Sendable {
    public var id: String
    public var title: String
    public var shortcut: Character?
    public var unavailableHelp: String?
    public init(id: String, title: String, shortcut: Character? = nil, unavailableHelp: String? = nil) {
        self.id = id; self.title = title; self.shortcut = shortcut; self.unavailableHelp = unavailableHelp
    }
}

public protocol ToolPicking: Sendable {
    /// The enabled tool whose one-key shortcut is `key` (case-insensitive), if any.
    func tool(forKey key: Character, in tools: [ToolFace]) -> String?
    /// The tooltip: "Brush (B)" while enabled, the reason while not.
    func help(for tool: ToolFace) -> String
    /// Ids that break the palette's rules: disabled with an empty reason, or a shortcut used twice.
    func violations(in tools: [ToolFace]) -> [String]
}

public struct FakeToolPicking: ToolPicking {
    public init() {}
    public func tool(forKey key: Character, in tools: [ToolFace]) -> String? {
        tools.first { $0.unavailableHelp == nil && $0.shortcut.map { $0.lowercased() == key.lowercased() } == true }?.id
    }
    public func help(for tool: ToolFace) -> String {
        if let reason = tool.unavailableHelp { return reason }
        return tool.shortcut.map { "\(tool.title) (\($0.uppercased()))" } ?? tool.title
    }
    public func violations(in tools: [ToolFace]) -> [String] {
        tools.filter { $0.unavailableHelp?.isEmpty == true }.map(\.id)
    }
}

// UC7 · SJ9, SP2 · Contracts/CanvasNavigating.swift
public protocol CanvasNavigating: Sendable {
    /// 0.1...32 (10 % to 3200 %); a zoom that isn't a number is 1.
    func clamped(_ zoom: Double) -> Double
    func zoomedIn(from zoom: Double) -> Double
    func zoomedOut(from zoom: Double) -> Double
    /// The zoom that fits `document` inside `viewport` less `margin` on every side; never a division by zero.
    func fit(document: PlaneExtent, in viewport: PlaneExtent, margin: Double) -> Double
    /// A view point (in the canvas's content, scrolled) to document pixels.
    func documentPoint(_ view: PlanePoint, artboardOrigin: PlanePoint, zoom: Double) -> PlanePoint
    /// How far an arrow key pans: a tenth of the viewport, ⇧ a whole one.
    func panStep(_ arrow: GridArrow, viewport: PlaneExtent, modifiers: KeyModifiers) -> PlanePoint
}

/// Doubles and halves instead of the live zoom stops.
public struct FakeCanvasNavigating: CanvasNavigating {
    public init() {}
    public func clamped(_ zoom: Double) -> Double { zoom.isFinite ? min(max(zoom, 0.1), 32) : 1 }
    public func zoomedIn(from zoom: Double) -> Double { clamped(zoom * 2) }
    public func zoomedOut(from zoom: Double) -> Double { clamped(zoom / 2) }
    public func fit(document: PlaneExtent, in viewport: PlaneExtent, margin: Double) -> Double {
        let w = viewport.width - 2 * margin, h = viewport.height - 2 * margin
        guard w > 0, h > 0, document.width > 0, document.height > 0 else { return 0.1 }
        return clamped(min(w / document.width, h / document.height))
    }
    public func documentPoint(_ view: PlanePoint, artboardOrigin: PlanePoint, zoom: Double) -> PlanePoint {
        let z = clamped(zoom)
        return PlanePoint(x: (view.x - artboardOrigin.x) / z, y: (view.y - artboardOrigin.y) / z)
    }
    public func panStep(_ arrow: GridArrow, viewport: PlaneExtent, modifiers: KeyModifiers) -> PlanePoint {
        let f = modifiers.contains(.shift) ? 1.0 : 0.1
        switch arrow {
        case .left: return PlanePoint(x: -viewport.width * f, y: 0)
        case .right: return PlanePoint(x: viewport.width * f, y: 0)
        case .up: return PlanePoint(x: 0, y: -viewport.height * f)
        case .down: return PlanePoint(x: 0, y: viewport.height * f)
        }
    }
}

// UC8 · SJ10, SP5 · Contracts/HandleGeometryProviding.swift
public enum HandleKind: String, Sendable, CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, rotate
}

public protocol HandleGeometryProviding: Sendable {
    /// Each handle's hit rect in view points around `rect` (view points at the current zoom). The hit size
    /// is `SuiteSize.selectionHandle`'s hit (12 pt) at every zoom; the rotate zone sits outside the top-right corner.
    func handles(around rect: PlaneRect, hitSize: Double) -> [HandleKind: PlaneRect]
    /// The handle under `point`, corners before edges before rotate; nil when none.
    func hit(_ point: PlanePoint, around rect: PlaneRect, hitSize: Double) -> HandleKind?
    /// `rect` after dragging `handle` by `delta`, the opposite side fixed; `keepAspect` (⇧) scales evenly.
    func resized(_ rect: PlaneRect, handle: HandleKind, by delta: PlanePoint, keepAspect: Bool) -> PlaneRect
    /// Degrees turned about `center` from `start` to `end`, clockwise positive (y-down), ⇧ snaps to 15°.
    func rotation(from start: PlanePoint, to end: PlanePoint, center: PlanePoint, snap: Bool) -> Double
}

/// Corner handles only; edges and rotate are never hit. Enough to draw handles, not for SJ10.
public struct FakeHandleGeometry: HandleGeometryProviding {
    public init() {}
    private func square(_ p: PlanePoint, _ s: Double) -> PlaneRect { PlaneRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s) }
    public func handles(around rect: PlaneRect, hitSize: Double) -> [HandleKind: PlaneRect] {
        [.topLeft: square(rect.origin, hitSize),
         .topRight: square(PlanePoint(x: rect.maxX, y: rect.minY), hitSize),
         .bottomRight: square(PlanePoint(x: rect.maxX, y: rect.maxY), hitSize),
         .bottomLeft: square(PlanePoint(x: rect.minX, y: rect.maxY), hitSize)]
    }
    public func hit(_ point: PlanePoint, around rect: PlaneRect, hitSize: Double) -> HandleKind? {
        handles(around: rect, hitSize: hitSize).first { $0.value.contains(point) }?.key
    }
    public func resized(_ rect: PlaneRect, handle: HandleKind, by delta: PlanePoint, keepAspect: Bool) -> PlaneRect {
        guard handle == .bottomRight else { return rect }
        return PlaneRect(x: rect.minX, y: rect.minY, width: max(rect.extent.width + delta.x, 0), height: max(rect.extent.height + delta.y, 0))
    }
    public func rotation(from start: PlanePoint, to end: PlanePoint, center: PlanePoint, snap: Bool) -> Double { 0 }
}

// UC9 · SJ18, SP4 · Contracts/GridSelecting.swift
public enum ClickKind: Sendable { case plain, extend, toggle }   // click, ⇧-click, ⌘-click

public struct GridPick<ID: Hashable & Sendable>: Equatable, Sendable {
    public var selection: Set<ID>
    public var anchor: ID?
    public init(selection: Set<ID> = [], anchor: ID? = nil) { self.selection = selection; self.anchor = anchor }
}

public protocol GridSelecting: Sendable {
    func click<ID: Hashable & Sendable>(_ id: ID, _ kind: ClickKind, current: GridPick<ID>, order: [ID]) -> GridPick<ID>
    func move<ID: Hashable & Sendable>(_ arrow: GridArrow, extend: Bool, current: GridPick<ID>, order: [ID], columns: Int) -> GridPick<ID>
    /// Adaptive columns for `width`; at least 1.
    func columns(width: Double, minimum: Double, spacing: Double) -> Int
}

/// Single selection only: every click selects just that item; arrows move one item and never extend.
public struct FakeGridSelecting: GridSelecting {
    public init() {}
    public func click<ID: Hashable & Sendable>(_ id: ID, _ kind: ClickKind, current: GridPick<ID>, order: [ID]) -> GridPick<ID> {
        order.contains(id) ? GridPick(selection: [id], anchor: id) : current
    }
    public func move<ID: Hashable & Sendable>(_ arrow: GridArrow, extend: Bool, current: GridPick<ID>, order: [ID], columns: Int) -> GridPick<ID> {
        guard let anchor = current.anchor, let i = order.firstIndex(of: anchor) else { return current }
        let step = switch arrow { case .left: -1; case .right: 1; case .up: -max(columns, 1); case .down: max(columns, 1) }
        let j = i + step
        guard order.indices.contains(j) else { return current }
        return GridPick(selection: [order[j]], anchor: order[j])
    }
    public func columns(width: Double, minimum: Double, spacing: Double) -> Int {
        guard minimum > 0, width.isFinite else { return 1 }
        return max(1, Int((width + spacing) / (minimum + spacing)))
    }
}

// UC10 · SJ17, SJ22 · Contracts/ListEditing.swift
public enum RenameOutcome: Equatable, Sendable {
    case renamed(String)
    case refused(message: String, draft: String)   // the row keeps the draft and shows the message
    case unchanged                                 // empty, whitespace only, or the same title
    case cancelled                                 // Escape
}

public protocol ListEditing: Sendable {
    /// `validate` is the app's check: nil accepts, a message refuses (#577).
    func commitRename(_ draft: String, original: String, validate: (String) -> String?) -> RenameOutcome
    func cancelRename(_ draft: String, original: String) -> RenameOutcome
    /// The order after moving `id` to `index` (an index in the order without it, clamped).
    func reordered<ID: Hashable & Sendable>(_ order: [ID], moving id: ID, to index: Int) -> [ID]
    /// Where a drop at `y` (points from the list's top) lands among `count` rows of `rowHeight`.
    func dropIndex(atY y: Double, rowHeight: Double, count: Int) -> Int
}

/// Never refuses and never trims: it ignores `validate`, so refusal UI can't be built on it.
public struct FakeListEditing: ListEditing {
    public init() {}
    public func commitRename(_ draft: String, original: String, validate: (String) -> String?) -> RenameOutcome {
        draft == original ? .unchanged : .renamed(draft)
    }
    public func cancelRename(_ draft: String, original: String) -> RenameOutcome { .cancelled }
    public func reordered<ID: Hashable & Sendable>(_ order: [ID], moving id: ID, to index: Int) -> [ID] {
        var rest = order.filter { $0 != id }
        guard rest.count < order.count else { return order }
        rest.insert(id, at: min(max(index, 0), rest.count))
        return rest
    }
    public func dropIndex(atY y: Double, rowHeight: Double, count: Int) -> Int {
        guard rowHeight > 0, y.isFinite else { return 0 }
        return min(max(Int((y / rowHeight).rounded()), 0), count)
    }
}

// UC11 · SJ19, SP3 · Contracts/TimelineMapping.swift
public struct TimelineScale: Hashable, Sendable {
    public var duration: Int          // frames; below 0 counts as 0
    public var frameWidth: Double     // points per frame; 0, negative or NaN maps every x to frame 0
    public init(duration: Int, frameWidth: Double) { self.duration = duration; self.frameWidth = frameWidth }
}

public struct RulerMarkSet: Equatable, Sendable {
    public var ticks: [Int]
    public var labels: [Int]
    public init(ticks: [Int], labels: [Int]) { self.ticks = ticks; self.labels = labels }
}

public protocol TimelineMapping: Sendable {
    func x(forFrame frame: Int, scale: TimelineScale) -> Double
    /// Always inside 0...duration.
    func frame(atX x: Double, scale: TimelineScale) -> Int
    /// The key nearest `x` within `tolerance` points, if any.
    func keyframe(nearX x: Double, in keyframes: [Int], tolerance: Double, scale: TimelineScale) -> Int?
    /// Ticks and labels inside the visible stretch only, so a long timeline costs no more than a short one.
    func rulerMarks(visible: ClosedRange<Double>, minimumSpacing: Double, scale: TimelineScale) -> RulerMarkSet
}

/// A label every 10 frames and no ticks.
public struct FakeTimelineMapping: TimelineMapping {
    public init() {}
    public func x(forFrame frame: Int, scale: TimelineScale) -> Double { Double(frame) * max(scale.frameWidth, 0) }
    public func frame(atX x: Double, scale: TimelineScale) -> Int {
        guard scale.frameWidth > 0, x.isFinite else { return 0 }
        return min(max(Int((x / scale.frameWidth).rounded()), 0), max(scale.duration, 0))
    }
    public func keyframe(nearX x: Double, in keyframes: [Int], tolerance: Double, scale: TimelineScale) -> Int? {
        keyframes.first { abs(self.x(forFrame: $0, scale: scale) - x) <= tolerance }
    }
    public func rulerMarks(visible: ClosedRange<Double>, minimumSpacing: Double, scale: TimelineScale) -> RulerMarkSet {
        let lo = frame(atX: visible.lowerBound, scale: scale), hi = frame(atX: visible.upperBound, scale: scale)
        return RulerMarkSet(ticks: [], labels: Array(stride(from: (lo / 10) * 10, through: hi, by: 10)))
    }
}

// UC12 · SJ19 · Contracts/KeyEditing.swift
public struct KeyRef: Hashable, Sendable {
    public var track: String
    public var frame: Int
    public init(track: String, frame: Int) { self.track = track; self.frame = frame }
}

public protocol KeyEditing: Sendable {
    /// The key the selection moves to with ← or → (`direction` −1 or +1): along the same track, nil at its ends (#63).
    func nextKey(after key: KeyRef, direction: Int, tracks: [String: [Int]]) -> KeyRef?
    /// Whole frames a drag of `points` moves keys by.
    func frameDelta(points: Double, scale: TimelineScale) -> Int
    /// Old key to new frame for moving `keys` by `delta`, clamped as a group so none leaves 0...duration.
    func moved(_ keys: Set<KeyRef>, by delta: Int, duration: Int) -> [KeyRef: Int]
}

/// Moves each key on its own, clamping each (the live rule clamps the group).
public struct FakeKeyEditing: KeyEditing {
    public init() {}
    public func nextKey(after key: KeyRef, direction: Int, tracks: [String: [Int]]) -> KeyRef? {
        let frames = (tracks[key.track] ?? []).sorted()
        guard let i = frames.firstIndex(of: key.frame), frames.indices.contains(i + direction) else { return nil }
        return KeyRef(track: key.track, frame: frames[i + direction])
    }
    public func frameDelta(points: Double, scale: TimelineScale) -> Int {
        scale.frameWidth > 0 && points.isFinite ? Int((points / scale.frameWidth).rounded()) : 0
    }
    public func moved(_ keys: Set<KeyRef>, by delta: Int, duration: Int) -> [KeyRef: Int] {
        Dictionary(uniqueKeysWithValues: keys.map { ($0, min(max($0.frame + delta, 0), max(duration, 0))) })
    }
}

// UC13 · SJ5 · Contracts/TransportStepping.swift
public struct TransportState: Hashable, Sendable {
    public var frame: Int
    public var duration: Int          // frames; 0 means nothing to play
    public var fps: Int
    public var isPlaying: Bool
    public var loops: Bool
    public init(frame: Int, duration: Int, fps: Int, isPlaying: Bool = false, loops: Bool = false) {
        self.frame = frame; self.duration = duration; self.fps = fps; self.isPlaying = isPlaying; self.loops = loops
    }
}

public struct TransportFace: Hashable, Sendable {
    public var playTitle: String              // "Play" or "Pause"
    public var unavailableHelp: String?       // every button's reason when nothing can play
    public var timecode: String               // "00:01 / 00:02"
    public init(playTitle: String, unavailableHelp: String?, timecode: String) {
        self.playTitle = playTitle; self.unavailableHelp = unavailableHelp; self.timecode = timecode
    }
}

public protocol TransportStepping: Sendable {
    /// Step `by` frames: stop at the ends, or wrap while `loops`.
    func stepped(_ state: TransportState, by frames: Int) -> TransportState
    func toStart(_ state: TransportState) -> TransportState
    func toEnd(_ state: TransportState) -> TransportState
    func face(_ state: TransportState) -> TransportFace
}

/// Never wraps and prints frames ("12 / 48") instead of a timecode.
public struct FakeTransportStepping: TransportStepping {
    public init() {}
    private func last(_ s: TransportState) -> Int { max(s.duration - 1, 0) }
    public func stepped(_ s: TransportState, by frames: Int) -> TransportState {
        var n = s; n.frame = min(max(s.frame + frames, 0), last(s)); return n
    }
    public func toStart(_ s: TransportState) -> TransportState { var n = s; n.frame = 0; return n }
    public func toEnd(_ s: TransportState) -> TransportState { var n = s; n.frame = last(s); return n }
    public func face(_ s: TransportState) -> TransportFace {
        TransportFace(playTitle: s.isPlaying ? "Pause" : "Play",
                      unavailableHelp: s.duration > 0 ? nil : "Nothing to play.",
                      timecode: "\(s.frame) / \(s.duration)")
    }
}

// UC14 · SJ6 · Contracts/StatusPillComposing.swift
public enum PillStyle: Hashable, Sendable { case plain, toggle(isOn: Bool), warning }

public struct StatusPill: Hashable, Sendable {
    public var text: String
    public var style: PillStyle
    public init(text: String, style: PillStyle = .plain) { self.text = text; self.style = style }
}

public protocol StatusPillComposing: Sendable {
    /// Zoom first ("200%", "–" for a zoom that isn't a number), then "1920 × 1080", then `trailing` in order.
    func pills(zoom: Double, documentSize: PlaneExtent, trailing: [StatusPill]) -> [StatusPill]
}

/// Prints the raw zoom ("2.0×").
public struct FakeStatusPillComposing: StatusPillComposing {
    public init() {}
    public func pills(zoom: Double, documentSize: PlaneExtent, trailing: [StatusPill]) -> [StatusPill] {
        [StatusPill(text: "\(zoom)×"), StatusPill(text: "\(Int(documentSize.width)) × \(Int(documentSize.height))")] + trailing
    }
}

// UC15 · SJ16, SJ20 · Contracts/CurvePointEditing.swift
public protocol CurvePointEditing: Sendable {
    /// Unit points (0...1 both ways), sorted by x, at least two. A click adds a point between its neighbours.
    func added(_ point: PlanePoint, to points: [PlanePoint]) -> (points: [PlanePoint], index: Int)?
    /// Moved, kept between its neighbours with a minimum gap; the ends keep their x.
    func moved(_ index: Int, to point: PlanePoint, in points: [PlanePoint]) -> [PlanePoint]
    /// Nil when the point is an end or the curve would drop under two points.
    func removed(_ index: Int, from points: [PlanePoint]) -> [PlanePoint]?
    /// Arrow nudges of 0.01, ⇧ 0.1.
    func nudged(_ index: Int, dx: Int, dy: Int, coarse: Bool, in points: [PlanePoint]) -> [PlanePoint]
}

/// Appends without sorting and never refuses a removal.
public struct FakeCurvePointEditing: CurvePointEditing {
    public init() {}
    public func added(_ point: PlanePoint, to points: [PlanePoint]) -> (points: [PlanePoint], index: Int)? {
        (points + [point], points.count)
    }
    public func moved(_ index: Int, to point: PlanePoint, in points: [PlanePoint]) -> [PlanePoint] {
        guard points.indices.contains(index) else { return points }
        var p = points; p[index] = point; return p
    }
    public func removed(_ index: Int, from points: [PlanePoint]) -> [PlanePoint]? {
        guard points.indices.contains(index) else { return nil }
        var p = points; p.remove(at: index); return p
    }
    public func nudged(_ index: Int, dx: Int, dy: Int, coarse: Bool, in points: [PlanePoint]) -> [PlanePoint] {
        guard points.indices.contains(index) else { return points }
        let s = coarse ? 0.1 : 0.01
        return moved(index, to: PlanePoint(x: points[index].x + Double(dx) * s, y: points[index].y + Double(dy) * s), in: points)
    }
}

// UC16 · SJ23 · Contracts/GraphGeometry.swift
public struct ArrowPath: Hashable, Sendable {
    public var start: PlanePoint
    public var end: PlanePoint
    public var controls: [PlanePoint]   // empty for a straight arrow
    public init(start: PlanePoint, end: PlanePoint, controls: [PlanePoint] = []) {
        self.start = start; self.end = end; self.controls = controls
    }
}

public protocol GraphGeometry: Sendable {
    /// From the edge of `from` to the edge of `to`, along the line between their centers.
    func arrow(from: PlaneRect, to: PlaneRect) -> ArrowPath
    /// A loop leaving and entering the top edge of `node`, drawn outside it.
    func selfLoop(around node: PlaneRect) -> ArrowPath
}

/// Center to center: arrows overlap their nodes.
public struct FakeGraphGeometry: GraphGeometry {
    public init() {}
    public func arrow(from: PlaneRect, to: PlaneRect) -> ArrowPath { ArrowPath(start: from.mid, end: to.mid) }
    public func selfLoop(around node: PlaneRect) -> ArrowPath { ArrowPath(start: node.mid, end: node.mid) }
}

// MARK: 5.3 Harness contracts

// UC17 · SP1–SP5, every QB-L row · Contracts/FrameProbeRecording.swift
public struct ProbeSample: Hashable, Sendable, Codable {
    public var series: String          // "bar-slider", "canvas-drag", ...
    public var eventTime: Double       // the input event's timestamp, seconds
    public var shownAt: Double         // the target timestamp of the first refresh that drew it
    public init(series: String, eventTime: Double, shownAt: Double) {
        self.series = series; self.eventTime = eventTime; self.shownAt = shownAt
    }
}

public struct ProbeSummary: Hashable, Sendable, Codable {
    public var count: Int
    public var p50FramesLate: Int
    public var p95FramesLate: Int
    public var valid: Bool             // at least 60 samples (section 7)
    public init(count: Int, p50FramesLate: Int, p95FramesLate: Int, valid: Bool) {
        self.count = count; self.p50FramesLate = p50FramesLate; self.p95FramesLate = p95FramesLate; self.valid = valid
    }
}

public protocol FrameProbeRecording: Sendable {
    mutating func record(_ sample: ProbeSample)
    /// An in-app moment: "preview-before-mouse-up", "progress-shown", "animation-ended" and the like.
    mutating func mark(_ name: String, at time: Double)
    /// Frames late = refreshes between the event and the refresh that showed it, at `refreshInterval` seconds.
    func summary(of series: String, refreshInterval: Double) -> ProbeSummary
    /// The `suite.perf` JSON.
    func encoded() throws -> Data
}

/// Keeps samples and marks; reports every sample as 0 frames late.
public struct FakeFrameProbe: FrameProbeRecording {
    public private(set) var samples: [ProbeSample] = []
    public private(set) var marks: [String: Double] = [:]
    public init() {}
    public mutating func record(_ sample: ProbeSample) { samples.append(sample) }
    public mutating func mark(_ name: String, at time: Double) { marks[name] = time }
    public func summary(of series: String, refreshInterval: Double) -> ProbeSummary {
        let n = samples.filter { $0.series == series }.count
        return ProbeSummary(count: n, p50FramesLate: 0, p95FramesLate: 0, valid: n >= 60)
    }
    public func encoded() throws -> Data { try JSONEncoder().encode(samples) }
}

// UC18 · SJ0, every app's every-control sweep · Contracts/ControlInventorying.swift
public struct ControlEntry: Hashable, Sendable, Codable {
    public var id: String
    public var enabled: Bool
    public var reason: String?
    public init(id: String, enabled: Bool, reason: String? = nil) { self.id = id; self.enabled = enabled; self.reason = reason }
}

public protocol ControlInventorying: Sendable {
    mutating func register(_ entry: ControlEntry)
    mutating func unregister(_ id: String)
    /// Ids that break "no dead controls": disabled with no reason, or an id registered twice.
    func violations() -> [String]
    /// The `suite.controls` JSON, sorted by id.
    func encoded() throws -> Data
}

/// Keeps the last entry per id; never reports a duplicate.
public struct FakeControlInventory: ControlInventorying {
    public private(set) var entries: [String: ControlEntry] = [:]
    public init() {}
    public mutating func register(_ entry: ControlEntry) { entries[entry.id] = entry }
    public mutating func unregister(_ id: String) { entries[id] = nil }
    public func violations() -> [String] {
        entries.values.filter { !$0.enabled && ($0.reason ?? "").isEmpty }.map(\.id).sorted()
    }
    public func encoded() throws -> Data { try JSONEncoder().encode(entries.values.sorted { $0.id < $1.id }) }
}

// UC19 · QB-V2–V5 · Contracts/GoldenComparing.swift (conformance in Tests/AppSnapshotTests/GoldenImage.swift)
public struct RGBAImage: Hashable, Sendable {
    public var width: Int
    public var height: Int
    public var bytes: [UInt8]   // width × height × 4, row-major, 8-bit sRGB
    public init(width: Int, height: Int, bytes: [UInt8]) { self.width = width; self.height = height; self.bytes = bytes }
}

public struct GoldenTolerance: Hashable, Sendable {
    public var channel: UInt8        // largest per-channel difference that still counts as equal
    public var maxShare: Double      // largest share of differing pixels that still passes
    public init(channel: UInt8 = 2, maxShare: Double = 0.005) { self.channel = channel; self.maxShare = maxShare }
    public static let standard = GoldenTolerance()
}

public struct GoldenResult: Hashable, Sendable {
    public var passes: Bool
    public var differing: Int
    public var share: Double
    public var diff: RGBAImage?      // differing pixels in magenta over a grey copy; nil when they match exactly
    public init(passes: Bool, differing: Int, share: Double, diff: RGBAImage?) {
        self.passes = passes; self.differing = differing; self.share = share; self.diff = diff
    }
}

public protocol GoldenComparing: Sendable {
    /// Different dimensions, or a malformed buffer, always fail with share 1.
    func compare(_ actual: RGBAImage, to baseline: RGBAImage, tolerance: GoldenTolerance) -> GoldenResult
}

/// Byte-for-byte equality, no diff image.
public struct FakeGoldenComparing: GoldenComparing {
    public init() {}
    public func compare(_ actual: RGBAImage, to baseline: RGBAImage, tolerance: GoldenTolerance) -> GoldenResult {
        actual == baseline ? GoldenResult(passes: true, differing: 0, share: 0, diff: nil)
                           : GoldenResult(passes: false, differing: max(actual.width * actual.height, 1), share: 1, diff: nil)
    }
}
