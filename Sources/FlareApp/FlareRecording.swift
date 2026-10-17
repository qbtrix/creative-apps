// FlareRecording.swift: the recording state (docs/design.md, States) laid
// over the stage and timeline while auto-key is on (draw-key-save DK-14): a
// 2 pt `stateRecording` ring round both, and in its top trailing corner the
// recording dot with a visible "Recording" caption whose tooltip says what
// the state does (#1845), so the state never rests on color alone. With
// auto-key off it draws nothing. The ring takes no clicks and hides from
// accessibility, so it never covers the stage or the lanes; only the small
// dot-and-caption badge takes the pointer, for its tooltip. The badge is the
// one element, "Recording" (`flare.recording`), that journeys find. It only
// reads `model`.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareRecording: View {
    static let caption = "Recording"
    static let explanation = "Auto-key on: moving a layer keys it at the playhead"
    let model: FlareWorkspace

    var body: some View {
        if model.autoKey {
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .strokeBorder(SuiteColor.stateRecording, lineWidth: SuiteSize.focusRing)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                HStack(spacing: SuiteSpacing.xs) {
                    Image(systemName: "circle.fill")
                        .resizable()
                        .frame(width: SuiteSize.statusDot, height: SuiteSize.statusDot)
                    Text(Self.caption)
                        .font(SuiteFont.caption)
                }
                .foregroundStyle(SuiteColor.stateRecording)
                .padding(SuiteSpacing.s)
                .contentShape(Rectangle())
                .help(Self.explanation)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.caption)
                .accessibilityValue(Self.explanation)
                .accessibilityIdentifier("flare.recording")
            }
        }
    }
}
