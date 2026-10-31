// AgentWorking.swift: the one "AI is working" treatment every app's AI tab
// shares, read from SuiteKernel's AgentWork (the open request span and the
// newest agent step). AgentWorkWatch holds the linger: while a span is open
// it shows that span's work, and a change AgentWork.wake names (a span
// begun or ended, a newer agent step) shows for AgentWork.linger (0.6 s)
// after it, so a burst of sub-second steps never flickers. It wakes on a
// change only, so a window opened on old history shows nothing.
// AgentWorkingMark is the sidebar's dot: `accent`, `statusDot` sized,
// pulsing through the system symbol effect (drawn by the render server, so
// no body runs per frame), still under Reduce Motion and in snapshots,
// labelled "AI is working: <request>". It is Equatable on its two values,
// so a window body that leaves AgentWork alone skips it. `.agentShimmer(_:)`
// sweeps an `accentText` band across a working title, an overlay masked by
// the text itself, so the finished row keeps the same layout and nothing
// jumps; under Reduce Motion it is a still `accentText` tint, in a snapshot
// the band holds mid-title. Idle, none of these runs a timer or a body.
import SuiteKernel
import SwiftUI

/// `content(shown)`: the open span's work, or for `AgentWork.linger` the work a change woke, else nil.
public struct AgentWorkWatch<Content: View>: View {
    private let work: AgentWork
    private let content: (AgentWork?) -> Content
    @State private var held: AgentWork?
    /// The newest agent step shown so far: an undo or redo back to an older one wakes nothing.
    @State private var seen = 0
    /// Bumped per wake; each restarts the linger.
    @State private var beat = 0

    public init(_ work: AgentWork, @ViewBuilder content: @escaping (AgentWork?) -> Content) {
        (self.work, self.content) = (work, content)
    }

    public var body: some View {
        content(work.request != nil ? work : held)
            .onAppear { seen = max(seen, work.lastStep ?? 0) }
            .onChange(of: work) { old, new in
                if let woke = AgentWork.wake(from: old, to: new, seen: seen) {
                    held = woke
                    beat += 1
                }
                seen = max(seen, new.lastStep ?? 0)
            }
            .task(id: beat) {
                guard beat > 0 else { return }
                try? await Task.sleep(for: .seconds(AgentWork.linger))
                if !Task.isCancelled { held = nil }
            }
    }
}

/// The sidebar's working dot beside the AI segment; nothing while idle.
public struct AgentWorkingMark: View, Equatable, BodyCounted {
    let work: AgentWork
    let id: String
    @Environment(\.bodyTally) private var bodyTally

    public init(_ work: AgentWork, id: String) { (self.work, self.id) = (work, id) }

    nonisolated public static func == (lhs: Self, rhs: Self) -> Bool { lhs.work == rhs.work && lhs.id == rhs.id }

    /// VoiceOver's name for the mark: "AI is working: <request>", or "AI is working" outside a span.
    nonisolated public static func label(_ work: AgentWork) -> String {
        work.request.map { "AI is working: \($0)" } ?? "AI is working"
    }

    public var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        AgentWorkWatch(work) { shown in
            if let shown { AgentWorkingDot(label: Self.label(shown), id: id) }
        }
    }
}

private struct AgentWorkingDot: View {
    let label: String
    let id: String
    @Environment(\.suiteReduceMotion) private var reduceMotion
    @Environment(\.suiteSnapshotRendering) private var snapshot

    var body: some View {
        Image(systemName: "circle.fill")
            .resizable()
            .frame(width: SuiteSize.statusDot, height: SuiteSize.statusDot)
            .foregroundStyle(SuiteColor.accent)
            .symbolEffect(.pulse, options: .repeating, isActive: AreaAnts.animates(reduceMotion: reduceMotion, snapshot: snapshot))
            .help(label)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityIdentifier(id)
    }
}

extension View {
    /// A working request's title: a band sweeping across the text while `active`, settling into the plain text.
    public func agentShimmer(_ active: Bool) -> some View { modifier(AgentShimmer(active: active)) }
}

private struct AgentShimmer: ViewModifier {
    let active: Bool
    @Environment(\.suiteReduceMotion) private var reduceMotion
    @Environment(\.suiteSnapshotRendering) private var snapshot

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    Group {
                        if reduceMotion { SuiteColor.accentText } else { AgentShimmerBand(moves: !snapshot) }
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
                }
            }
            .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: active)
    }
}

/// Half the title wide, it sweeps from before the text to past it once per `SuiteMotion.shimmerSweep`.
private struct AgentShimmerBand: View {
    let moves: Bool
    @State private var swept = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            LinearGradient(colors: [.clear, SuiteColor.accentText, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: width / 2)
                .offset(x: moves ? (swept ? width : -width / 2) : width / 4)
        }
        .onAppear {
            guard moves else { return }
            withAnimation(.linear(duration: SuiteMotion.shimmerSweep).repeatForever(autoreverses: false)) { swept = true }
        }
    }
}
