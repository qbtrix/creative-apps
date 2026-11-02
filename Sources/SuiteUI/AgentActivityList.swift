// AgentActivityList.swift: the AI tab, every request an agent made in the
// document (SuiteKernel AgentRequests), drawn on LayerTreeList so a request
// looks and behaves like a layer group. A request row (newest first) shows
// its title with "client · time · N steps" as its caption; it opens to its
// steps (by name) and the layers they created or changed. Each row's eye
// shows or hides that row's layers (`setHidden`, one undo step in the app;
// `showsEye: false` drops the eyes for an app whose layers can't hide, and
// `undoHelp` disables Undo Request with the app's reason);
// a click selects them; the context menu holds Select Layers, Undo Request
// (the newest named request only, as `history.undo-request {title}` refuses
// any other) and Keep, which only
// closes the row. Which rows are open is this view's own state, so opening
// the tab or a row runs no app body and no canvas render. The list mutates
// nothing: every gesture goes out through `onAction`. With no requests it
// shows "No agent actions yet." and the `afterglow mcp --live` hint. While
// an agent works (`work`, through AgentWorkWatch's linger) its request reads
// as live: it opens once, its title shimmers, its step count ticks and each
// new step eases in; when the work ends the shimmer fades into the plain row
// in place. `liveRequest` is the rule for which row that is. Ids:
// `suite.agent`, rows `suite.agent.row.<id>`, eyes `suite.agent.<id>.eye`.
import SuiteKernel
import SwiftUI

/// What a person did in the AI tab.
public enum AgentActivityAction: Equatable, Sendable {
    /// Hide (true) or show the layers, as one step.
    case setHidden([String], Bool)
    /// Select exactly these layers.
    case select([String])
    /// Undo the request with this title (`history.undo-request`).
    case undoRequest(String)
}

public struct AgentActivityList: View {
    private let requests: [AgentRequest]
    private let layerNames: [String: String]
    private let hidden: Set<String>
    private let timeZone: TimeZone
    private let showsEye: Bool
    private let undoHelp: String?
    private let work: AgentWork
    private let onAction: @MainActor (AgentActivityAction) -> Void
    @State private var expanded: Set<String>
    @Environment(\.suiteReduceMotion) private var reduceMotion

    public static let naming = LayerTreeNaming.app(
        LayerTreeIDs(container: "suite.agent", row: "suite.agent.row.", control: "suite.agent."))
    public static let emptyTitle = "No agent actions yet."
    public static let emptyHint = "Connect an agent with afterglow mcp --live and its edits show up here."

    /// `layerNames` names each layer id (a gone layer shows its id); `hidden` holds the hidden layers' ids.
    /// `showsEye` false drops the eyes, for an app whose layers can't hide. `undoHelp` disables Undo Request
    /// on every request with that reason, for an app that can't undo a request as one. `work` is the
    /// document's AgentWork, which marks the request under way live.
    public init(requests: [AgentRequest], layerNames: [String: String], hidden: Set<String>,
                expanded: Set<String> = [], timeZone: TimeZone = .current, showsEye: Bool = true,
                undoHelp: String? = nil, work: AgentWork = AgentWork(),
                onAction: @escaping @MainActor (AgentActivityAction) -> Void) {
        (self.requests, self.layerNames, self.hidden, self.timeZone, self.showsEye, self.onAction)
            = (requests, layerNames, hidden, timeZone, showsEye, onAction)
        (self.undoHelp, self.work) = (undoHelp, work)
        _expanded = State(initialValue: expanded)
    }

    public var body: some View {
        if requests.isEmpty {
            EmptyStateView(Self.emptyTitle, systemImage: "sparkles", message: Self.emptyHint)
                .accessibilityIdentifier("suite.agent.empty")
        } else {
            AgentWorkWatch(work) { shown in
                let live = Self.liveRequest(requests, shown: shown)
                LayerTreeList(
                    rows: Self.rows(requests, expanded: expanded, names: layerNames, hidden: hidden),
                    childCount: { id in requests.first { $0.id == id }.map { $0.steps.count + $0.layers.count } ?? 0 },
                    naming: Self.naming, options: LayerTreeOptions(showsEye: showsEye, showsLock: false),
                    decorations: Self.decorations(requests, timeZone: timeZone, live: live),
                    onSelect: { onAction(.select(layers(of: $0))) },
                    contextActions: { menu(for: $0) },
                    onAction: handle)
                // A new step of the live request eases in and its count ticks; nothing moves otherwise.
                .animation(SuiteMotion.state(reduceMotion: reduceMotion),
                           value: requests.first { $0.id == live }?.steps.count ?? 0)
                .onChange(of: live, initial: true) { _, id in if let id { expanded.insert(id) } }
            }
        }
    }

    private func handle(_ action: LayerTreeAction) {
        switch action {
        case .disclose(let id):
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        case .toggleHidden(let id):
            // ponytail: a step row with no layers has an inert eye; hide the eye per row if LayerTreeList grows that option.
            let ids = layers(of: id)
            if !ids.isEmpty { onAction(.setHidden(ids, !ids.allSatisfy(hidden.contains))) }
        case .toggleLocked, .move: break
        }
    }

    private func menu(for id: String) -> [ToolbarAction] {
        var items = [ToolbarAction("Select Layers", systemImage: "checkmark.circle",
                                   unavailableHelp: layers(of: id).isEmpty ? "These steps changed no layer." : nil,
                                   identifier: Self.naming.control(id, "select")) { onAction(.select(layers(of: id))) }]
        guard let request = requests.first(where: { $0.id == id }) else { return items }
        items.append(ToolbarAction("Undo Request", systemImage: "arrow.uturn.backward",
                                   unavailableHelp: Self.undoHelp(request, newest: requests.first?.id == id, app: undoHelp),
                                   identifier: Self.naming.control(id, "undo")) { onAction(.undoRequest(request.title)) })
        items.append(ToolbarAction("Keep", systemImage: "checkmark", identifier: Self.naming.control(id, "keep")) {
            expanded.remove(id)
        })
        return items
    }

    /// Why Undo Request can't run on `request`, nil when it can: the app's own reason (`app`) first, then
    /// not the newest (history.undo-request refuses all but the applied tail), then not a named request.
    nonisolated static func undoHelp(_ request: AgentRequest, newest: Bool, app: String? = nil) -> String? {
        if let app { return app }
        if !newest { return "Undo the newer requests first." }
        return request.isSpan ? nil : "Only a named request (history.begin) can be undone as one."
    }

    /// The request under way while `shown` (AgentWorkWatch's work) is: the newest, when it is the shown span,
    /// or outside a span when it holds the shown step; nil when idle.
    nonisolated public static func liveRequest(_ requests: [AgentRequest], shown: AgentWork?) -> String? {
        guard let shown, let newest = requests.first else { return nil }
        if let title = shown.request { return newest.isSpan && newest.title == title ? newest.id : nil }
        return !newest.isSpan && newest.steps.last?.id == shown.lastStep ? newest.id : nil
    }

    /// The layers row `id` stands for: a request's, a step's or the one layer.
    func layers(of id: String) -> [String] { Self.layers(of: id, in: requests) }

    nonisolated static func layers(of id: String, in requests: [AgentRequest]) -> [String] {
        for request in requests {
            if request.id == id { return request.layers }
            for step in request.steps where stepID(request, step) == id { return step.layers }
            for layer in request.layers where layerID(request, layer) == id { return [layer] }
        }
        return []
    }

    nonisolated static func stepID(_ request: AgentRequest, _ step: AgentStepRecord) -> String { "\(request.id).step.\(step.id)" }
    nonisolated static func layerID(_ request: AgentRequest, _ layer: String) -> String { "\(request.id).layer.\(layer)" }

    /// The list's rows: each request, then, when open, its steps and its layers one level in.
    nonisolated public static func rows(_ requests: [AgentRequest], expanded: Set<String>, names: [String: String],
                                        hidden: Set<String>) -> [LayerRow] {
        requests.flatMap { request -> [LayerRow] in
            let open = expanded.contains(request.id)
            let allHidden = !request.layers.isEmpty && request.layers.allSatisfy(hidden.contains)
            var rows = [LayerRow(id: request.id, name: request.title, depth: 0, isHidden: allHidden, isLocked: false,
                                 inheritsHidden: false, inheritsLocked: false, holdsChildren: true, isExpanded: open)]
            guard open else { return rows }
            for step in request.steps {
                rows.append(child(stepID(request, step), step.name,
                                  hidden: !step.layers.isEmpty && step.layers.allSatisfy(hidden.contains), under: allHidden))
            }
            for layer in request.layers {
                rows.append(child(layerID(request, layer), names[layer] ?? layer, hidden: hidden.contains(layer), under: allHidden))
            }
            return rows
        }
    }

    nonisolated private static func child(_ id: String, _ name: String, hidden: Bool, under: Bool) -> LayerRow {
        LayerRow(id: id, name: name, depth: 1, isHidden: hidden, isLocked: false, inheritsHidden: under,
                 inheritsLocked: false, holdsChildren: false, isExpanded: false)
    }

    /// Each request row's caption ("claude · 2:14 PM · 3 steps") and each child's kind symbol; the `live`
    /// request's row shimmers.
    nonisolated public static func decorations(_ requests: [AgentRequest], timeZone: TimeZone,
                                               live: String? = nil) -> [String: LayerRowDecoration] {
        var out: [String: LayerRowDecoration] = [:]
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        for request in requests {
            out[request.id] = LayerRowDecoration(symbol: "sparkles", symbolLabel: "Agent request",
                                                 caption: caption(request, style: style), live: request.id == live)
            for step in request.steps {
                out[stepID(request, step)] = LayerRowDecoration(symbol: "arrow.turn.down.right", symbolLabel: "Step")
            }
            for layer in request.layers {
                out[layerID(request, layer)] = LayerRowDecoration(symbol: "square.3.layers.3d", symbolLabel: "Layer")
            }
        }
        return out
    }

    nonisolated static func caption(_ request: AgentRequest, style: Date.FormatStyle) -> String {
        let count = request.steps.count
        return "\(request.client) · \(request.date.formatted(style)) · \(count) step\(count == 1 ? "" : "s")"
    }
}
