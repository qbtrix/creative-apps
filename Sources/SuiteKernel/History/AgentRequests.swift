// AgentRequests.swift: an agent's steps in a document grouped into requests,
// what the AI tab (SuiteUI AgentActivityList) lists. A step comes in as an
// AgentStepRecord: its history step id, name, the client that ran it, the
// request title of the `history.begin`/`history.end` span it ran in (nil
// outside one), when it ran and the layer ids it created or changed. Steps
// in one span form one request named by the span; steps outside a span from
// one client, each within `gap` (60 s) of the one before, form one request
// named by its first step. Requests come out newest first, each with its
// steps in order and its layers once each. User steps never come in:
// `History.agentSteps` keeps only steps whose origin is `.agent` (#6028), with
// each one's record time from AgentStepDates (History keeps no date), which an
// app's history stamps after every record. An app adapter adds only how a
// step's undo payload names its layers. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One agent step as the AI tab reads it.
public struct AgentStepRecord: Hashable, Sendable {
    public var id: Int
    public var name: String
    public var client: String
    /// The span's title (`history.begin {name}`), nil outside a span.
    public var request: String?
    public var date: Date
    /// The layers the step created or changed.
    public var layers: [String]

    public init(id: Int, name: String, client: String, request: String? = nil, date: Date, layers: [String] = []) {
        (self.id, self.name, self.client, self.request, self.date, self.layers) = (id, name, client, request, date, layers)
    }
}

/// One request: its steps and the layers they touched.
public struct AgentRequest: Hashable, Sendable, Identifiable {
    /// "agent.<first step id>": stable while its steps stay.
    public var id: String
    public var title: String
    public var client: String
    /// When its last step ran.
    public var date: Date
    public var steps: [AgentStepRecord]
    /// Every touched layer once, in the order first touched.
    public var layers: [String]
    /// Whether it came from a span (so `history.undo-request {title}` names it).
    public var isSpan: Bool
}

public enum AgentRequests {
    /// The longest pause between two of one client's steps outside a span that keeps them one request.
    public static let gap: TimeInterval = 60

    /// `steps` (oldest first) grouped into requests, newest first.
    public static func group(_ steps: [AgentStepRecord], gap: TimeInterval = gap) -> [AgentRequest] {
        var out: [AgentRequest] = []
        for step in steps {
            if var last = out.last, joins(step, last, gap: gap) {
                last.steps.append(step)
                last.date = step.date
                for id in step.layers where !last.layers.contains(id) { last.layers.append(id) }
                out[out.count - 1] = last
            } else {
                var layers: [String] = []
                for id in step.layers where !layers.contains(id) { layers.append(id) }
                out.append(AgentRequest(id: "agent.\(step.id)", title: step.request ?? step.name, client: step.client,
                                        date: step.date, steps: [step], layers: layers, isSpan: step.request != nil))
            }
        }
        return out.reversed()
    }

    private static func joins(_ step: AgentStepRecord, _ request: AgentRequest, gap: TimeInterval) -> Bool {
        guard step.client == request.client, let prev = request.steps.last else { return false }
        if let title = step.request { return request.isSpan && title == request.title && prev.request == title }
        return !request.isSpan && step.date.timeIntervalSince(prev.date) <= gap
    }
}

/// When each agent step was recorded, by its `idAfter` (History keeps no date): the AI tab's time.
public struct AgentStepDates: Sendable, Hashable {
    public private(set) var dates: [Int: Date] = [:]

    public init() {}

    /// Stamps the step `history` just recorded when an agent made it; once the
    /// stamps outnumber twice `limit`, drops those of steps it no longer holds.
    public mutating func stamp<Payload>(_ history: History<Payload>, limit: Int) {
        guard let last = history.undoSteps.last, case .agent = last.origin else { return }
        dates[last.idAfter] = Date()
        if dates.count > 2 * limit {
            let live = Set(history.undoSteps.map(\.idAfter) + history.redoSteps.map(\.idAfter))
            dates = dates.filter { live.contains($0.key) }
        }
    }
}

extension History {
    /// The applied agent steps, oldest first, timed by `dates`. `layers` reads each step's layers from the step
    /// and the applied step after it (nil for the newest: the document now), so a later edit, an agent's or a
    /// person's, never joins an older step's layers.
    public func agentSteps(dates: AgentStepDates, layers: (Step, Step?) -> [String] = { _, _ in [] }) -> [AgentStepRecord] {
        let next = undoSteps.dropFirst().map(Optional.some) + [nil]
        return zip(undoSteps, next).compactMap { step, after in
            guard case .agent(let client, let request) = step.origin else { return nil }
            return AgentStepRecord(id: step.idAfter, name: step.name, client: client, request: request,
                                   date: dates.dates[step.idAfter] ?? .distantPast, layers: layers(step, after))
        }
    }
}
