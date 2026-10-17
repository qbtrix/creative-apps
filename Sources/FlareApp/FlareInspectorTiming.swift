// FlareInspectorTiming.swift: the TIMING stub (IT-4): it holds the window's
// FlareEasingInspector, so the easing journey passes until IT-8 replaces it.
import SwiftUI

struct FlareInspectorTiming<Easing: View>: View {
    let easing: Easing

    var body: some View { easing }
}
