// DesignTimelineTracks.swift: what Design's timeline slot shows (one-document OD-12). One row per keyed layer on
// the selected page, in layer-tree order (a parent before its children), each with every key of its x, y and
// opacity tracks merged by frame; a frame keyed on several properties draws once, shaped by the easing of the
// first of them in DesignKeyProperty order. The slot shows while the document has keys (`showsTimeline`, the
// slide-in rule: a still document never shows it). The window maps rows to SuiteUI's TimelineTrack, so this file
// stays free of SwiftUI. Linux-safe.
import SuiteKernel

/// One timeline row: a keyed layer and its keys.
public struct DesignTimelineRow: Hashable, Sendable, Identifiable {
    /// How a key draws, from the easing that leaves it.
    public enum Shape: String, Hashable, Sendable { case linear, eased, hold }

    public struct Key: Hashable, Sendable {
        public let frame: Int
        public let shape: Shape
    }

    public let id: String
    public let name: String
    public let keys: [Key]
}

extension DesignWorkspace {
    /// The slide-in rule: the timeline shows once any layer has a key, and never on a still document.
    public var showsTimeline: Bool { !isStill }

    /// The selected page's keyed layers, parents first, each with its keys merged by frame.
    public var timelineRows: [DesignTimelineRow] {
        var rows: [DesignTimelineRow] = []
        func visit(_ nodes: [DesignNode]) {
            for node in nodes {
                if let time = node.time, !time.isEmpty {
                    rows.append(DesignTimelineRow(id: node.id, name: node.name, keys: Self.keys(of: time)))
                }
                visit(node.children)
            }
        }
        visit(selectedPage?.nodes ?? [])
        return rows
    }

    /// The last frame the timeline spans: the document's length less one.
    public var timelineLastFrame: Int { max(time.durationFrames - 1, 0) }

    private static func keys(of time: DesignNodeTime) -> [DesignTimelineRow.Key] {
        var byFrame: [Int: DesignTimelineRow.Shape] = [:]
        for property in DesignKeyProperty.allCases {
            for key in time.tracks[property] ?? [] where byFrame[key.frame] == nil {
                byFrame[key.frame] = shape(key.easing)
            }
        }
        return byFrame.keys.sorted().map { DesignTimelineRow.Key(frame: $0, shape: byFrame[$0]!) }
    }

    private static func shape(_ easing: Easing) -> DesignTimelineRow.Shape {
        switch easing {
        case .linear: .linear
        case .hold: .hold
        case .cubicBezier: .eased
        }
    }
}
