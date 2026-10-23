// HaloTransportState.swift: what the status bar's transport draws (#4352),
// worked out from one project: the frame shown (HaloLiveNeed.playhead), so
// while a ruler scrub or a playing frame is live, before the window takes it
// back, each button's enabled state, its tooltip and its ink all come from
// this one value in one view pass. A scrub that ends on the last frame shows
// Next and End disabled and Start and Previous enabled at once, not 0.2 s
// later (HaloLivePlayhead.settle). Equatable, so a playing frame that leaves
// every button as it was skips the buttons' body. Linux-safe
// (HaloTransportStateTests).

public struct HaloTransportState: Sendable, Equatable {
    /// One transport button: its command, title and why it can't act.
    public struct Button: Sendable, Equatable, Identifiable {
        public let command: HaloCommand
        public let title: String
        /// Why the command can't act now; nil while it can.
        public let unavailableHelp: String?
        /// The menu item's help, worded as its catalog spec's
        /// ("<title>: <why>" while it can't act, else the spec's summary).
        public let menuHelp: String

        public var id: HaloCommand { command }
        public var isEnabled: Bool { unavailableHelp == nil }
    }

    /// The transport's commands, in the order its buttons sit.
    public static let commands: [HaloCommand] = [.goToStart, .previousFrame, .playPause, .nextFrame, .goToEnd, .toggleLoop]

    public let buttons: [Button]
    public let playing: Bool
    public let loops: Bool
    public let playLabel: String
    public let loopLabel: String

    /// The transport for `project`, the frame on screen.
    public init(_ project: HaloProject) {
        buttons = Self.commands.map { command in
            let title = project.title(for: command), why = project.unavailableHelp(for: command)
            return Button(command: command, title: title, unavailableHelp: why,
                          menuHelp: why.map { "\(title): \($0)" } ?? HaloMenuState.spec(command.commandID).summary)
        }
        playing = project.playback.playing
        loops = project.playback.loops
        playLabel = project.playLabel
        loopLabel = project.loopLabel
    }

    /// The commands whose buttons are enabled now.
    public var enabled: Set<HaloCommand> { Set(buttons.filter(\.isEnabled).map(\.command)) }
}
