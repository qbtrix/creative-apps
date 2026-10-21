// ShareButton.swift (share-sheet SH-2): the one Share control over the system's
// share sheet (SwiftUI's `ShareLink`), so every app shares the same way (packet
// docs/blueprints/library/features/share-sheet.md). Pressed, it awaits
// `prepare` (the app's share copies) with a spinner, then offers "Share N
// Photos", the `ShareLink` that opens the system sheet for those files. While
// `help` is set it is disabled and the tooltip says why; a failed prepare shows
// its reason the same way until the next press. A change of `help` (a new
// selection) drops prepared files. Owns presentation state only: the phase.
import SwiftUI

/// Where a share is: nothing yet, preparing, the files ready, or why preparing failed.
public enum SharePhase: Equatable, Sendable {
    case idle, preparing, ready([URL]), failed(String)

    /// The button's title.
    public var title: String {
        guard case .ready(let urls) = self else { return "Share…" }
        return urls.count == 1 ? "Share 1 Photo" : "Share \(urls.count) Photos"
    }

    /// Whether the button can be pressed, given the host's reason it can't share.
    public func isEnabled(help: String?) -> Bool { help == nil && self != .preparing }

    /// The tooltip: the host's reason first, then a failed prepare's.
    public func tooltip(help: String?) -> String {
        if let help { return help }
        switch self {
        case .idle: return "Share the selected photos."
        case .preparing: return "Preparing the photos to share…"
        case .ready: return "Opens the share sheet."
        case .failed(let reason): return reason
        }
    }

    /// The phase after `prepare` returns or throws; no files is a failure, never a silent share.
    public static func finished(_ result: Result<[URL], any Error>) -> SharePhase {
        switch result {
        case .success(let urls) where urls.isEmpty: .failed("There was nothing to share.")
        case .success(let urls): .ready(urls)
        case .failure(let error): .failed(reason(error))
        }
    }

    /// A localized error's description, else the error as text.
    static func reason(_ error: any Error) -> String {
        (error as? any LocalizedError)?.errorDescription ?? String(describing: error)
    }
}

public struct ShareButton: View {
    private let help: String?
    private let prepare: @MainActor () async throws -> [URL]
    @State private var phase = SharePhase.idle

    public init(help: String?, prepare: @escaping @MainActor () async throws -> [URL]) {
        self.help = help
        self.prepare = prepare
    }

    public var body: some View {
        Group {
            if case .ready(let urls) = phase, help == nil {
                ShareLink(items: urls) { Label(phase.title, systemImage: "square.and.arrow.up") }
            } else {
                Button(action: start) {
                    if phase == .preparing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(phase.title, systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(!phase.isEnabled(help: help))
            }
        }
        .help(phase.tooltip(help: help))
        .accessibilityLabel(phase.title)
        .accessibilityIdentifier("suite.share")
        .onChange(of: help) { phase = .idle }
    }

    private func start() {
        phase = .preparing
        Task { @MainActor in
            do { phase = SharePhase.finished(.success(try await prepare())) } catch {
                phase = SharePhase.finished(.failure(error))
            }
        }
    }
}
