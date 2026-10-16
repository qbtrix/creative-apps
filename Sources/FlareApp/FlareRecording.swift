// FlareRecording.swift: the recording state (docs/design.md, States) laid
// over the stage and timeline while auto-key is on (draw-key-save DK-14): a
// 2 pt `stateRecording` ring round both, and the recording dot in its top
// trailing corner, so the state never rests on color alone. With auto-key off
// it draws nothing. It takes no clicks, and the ring hides from
// accessibility, so it never covers the stage or the lanes; the dot is the
// one element, "Recording" (`flare.recording`), that journeys find. It only
// reads `model`.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareRecording: View {
    let model: FlareWorkspace

    var body: some View {
        if model.autoKey {
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .strokeBorder(SuiteColor.stateRecording, lineWidth: SuiteSize.focusRing)
                    .accessibilityHidden(true)
                Image(systemName: "circle.fill")
                    .resizable()
                    .frame(width: SuiteSize.statusDot, height: SuiteSize.statusDot)
                    .foregroundStyle(SuiteColor.stateRecording)
                    .padding(SuiteSpacing.s)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Recording")
                    .accessibilityValue("Auto-key on: moving a layer keys it at the playhead")
                    .accessibilityIdentifier("flare.recording")
            }
            .allowsHitTesting(false)
        }
    }
}
