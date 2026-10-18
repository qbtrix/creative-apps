// BusyNote.swift: the one "work in progress" note every app shows while it
// opens, saves, merges or imports. Without `fraction` it is a small spinner and
// the text on a GlassPanel, for an overlay over the window or canvas. With
// `fraction` it is a full-width panel row: the text in caption over a
// determinate bar (an import's "Importing 3 of 27").
//
// `delay` keeps a quick job from flashing the note: the note starts hidden and
// shows once `delay` has passed, restarting when `identifier` changes (a new
// job), never when only `text` does (an import's count ticking). A zero-size
// placeholder always exists, so the delay's `.task` runs while the note is
// hidden (#1379: a task on an empty Group never ran).
//
// The note is one accessibility element, `identifier`, labelled with `text`
// (XCUITest reads a SwiftUI value as "", so journeys read the label); the bar
// form also carries the text as its value.
import SwiftUI

public struct BusyNote: View {
    public let text: String
    public let identifier: String
    public let fraction: (value: Double, total: Double)?
    public let delay: Duration
    @State private var shown: Bool

    /// `fraction` is done of total (clamped to 0...total, total at least 1); nil draws the spinner.
    public init(
        _ text: String, identifier: String, fraction: (done: Int, total: Int)? = nil, delay: Duration = .zero
    ) {
        self.text = text
        self.identifier = identifier
        self.fraction = fraction.map { done, total in
            let total = max(total, 1)
            return (Double(min(max(done, 0), total)), Double(total))
        }
        self.delay = delay
        _shown = State(initialValue: delay <= .zero)
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: CGFloat.zero, height: CGFloat.zero)
            if shown {
                note
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(text)
                    .accessibilityValue(fraction == nil ? "" : text)
                    .accessibilityIdentifier(identifier)
            }
        }
        .task(id: identifier) {
            guard delay > .zero else { return }
            shown = false
            try? await Task.sleep(for: delay)
            if !Task.isCancelled { shown = true }
        }
    }

    @ViewBuilder private var note: some View {
        if let fraction {
            VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                Text(text)
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.textSecondary)
                ProgressView(value: fraction.value, total: fraction.total)
                    .progressViewStyle(.linear)
            }
            .padding(.horizontal, SuiteSpacing.m)
            .padding(.vertical, SuiteSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SuiteColor.panel)
        } else {
            GlassPanel {
                HStack(spacing: SuiteSpacing.s) {
                    ProgressView().controlSize(.small)
                    Text(text).font(SuiteFont.body)
                }
            }
        }
    }
}
