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
// step's undo payload names its layers. AgentWork is what the "AI is
// working" marks read (SuiteUI AgentWorking): the open span's name and the
// newest applied step when an agent made it, O(1) from History, with the
// rule for when a change wakes the marks and how long they linger
// (`linger`, 0.6 s) so a burst of sub-second steps never flickers. Linux-safe.
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

/// What the "AI is working" marks read: the open request span and the newest applied step when an agent made it.
public struct AgentWork: Hashable, Sendable {
    /// The open span's name (`history.begin`), nil when none is open.
    public var request: String?
    /// The id (`idAfter`) of the last applied step when an agent made it, nil when a person did or there is none.
    public var lastStep: Int?

    public init(request: String? = nil, lastStep: Int? = nil) { (self.request, self.lastStep) = (request, lastStep) }

    /// How long the marks stay after the last step or the span's end, so a burst of fast steps never flickers.
    public static let linger: Double = 0.6

    /// The work to show for `linger` after the change from `old` to `new`, nil when the change is no agent
    /// activity. `seen` is the newest agent step already shown: an undo or redo back to an older one wakes nothing.
    /// An ended span keeps its name while it lingers.
    public static func wake(from old: AgentWork, to new: AgentWork, seen: Int) -> AgentWork? {
        if old.request != nil, new.request == nil { return old }
        if new.request != old.request { return new }
        if let step = new.lastStep, step > seen { return new }
        return nil
    }
}

extension History {
    /// The open span and the newest applied step if an agent made it: O(1), safe to read in any body.
    public var agentWork: AgentWork {
        guard let last = undoSteps.last, case .agent = last.origin else { return AgentWork(request: openRequest) }
        return AgentWork(request: openRequest, lastStep: last.idAfter)
    }
}
