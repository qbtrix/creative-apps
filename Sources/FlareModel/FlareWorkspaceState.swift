// FlareWorkspaceState.swift: the value types FlareWorkspace stores for export, assist and file loading
// (docs/blueprints/flare.md, section 2). Each area's extension file (FlareExport, FlareAssist, FlareFiles) drives them.
import FlareCore

/// The export sheet's run: none yet, under way at a fraction done, finished, or failed with a message.
public enum ExportState: Equatable, Sendable {
    case idle
    case running(progress: Double)
    case finished(ExportResult)
    case failed(String)
}

/// The Assist popover: the prompt typed, the proposal made, the stage it would give, and why the last ask failed.
public struct AssistState: Equatable, Sendable {
    public var prompt: String
    public var proposal: AssistProposal?
    /// The stage with the proposal applied, for the popover's preview; nil with no proposal.
    public var preview: StageDrawList?
    public var error: AssistError?

    public init(prompt: String = "", proposal: AssistProposal? = nil, preview: StageDrawList? = nil,
                error: AssistError? = nil) {
        self.prompt = prompt; self.proposal = proposal; self.preview = preview; self.error = error
    }
}

/// Opening a file: nothing pending, reading and decoding off the main thread, or failed with a message.
public enum LoadState: Equatable, Sendable {
    case idle, loading
    case failed(String)
}
