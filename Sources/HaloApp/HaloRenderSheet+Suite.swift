// HaloRenderSheet+Suite.swift: the render sheet's codec and transparency rows
// (export-pack HX-2), in HaloRenderOptionRows under the Size chips. A movie
// shows the Codec row, a system Picker over `HaloRenderSettings.codecs`
// (`halo.render.codec`) whose refused codecs are disabled items, their
// reasons the row's help ("ProRes 4444 isn't available yet."). Every format shows
// the Transparent background checkbox (`halo.render.alpha`), disabled with the
// Model's `alphaRefusal` as its help ("H.264 can't keep transparency. Choose
// ProRes 4444."); a PNG sequence may always keep it. Each edit goes to the
// Model through `setRenderSettings` with the settings' `choosing(...)`.
import HaloModel
import SuiteModel
import SuiteUI
import SwiftUI

struct HaloRenderMovieRows: View {
    let settings: HaloRenderSettings
    /// True while the run is being set up; a running or ended run says `busy`.
    let editing: Bool
    let busy: String
    let act: @MainActor (HaloRenderAct) -> Void

    /// The Codec row's help: why each codec that can't be picked waits, or nil when all can.
    nonisolated static func codecHelp(busy: String?) -> String? {
        if let busy { return busy }
        let reasons = HaloRenderSettings.codecs.compactMap(HaloRenderSettings.codecRefusal)
        return reasons.isEmpty ? nil : reasons.joined(separator: " ")
    }

    /// The checkbox's help: why it is off, or nil while it may change.
    nonisolated static func alphaHelp(_ settings: HaloRenderSettings, busy: String?) -> String? {
        busy ?? settings.alphaRefusal
    }

    var body: some View {
        let busyHelp = editing ? nil : busy
        let alphaHelp = Self.alphaHelp(settings, busy: busyHelp)
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            if settings.format == .movie {
                VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                    Text("Codec").font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.textSecondary)
                    Picker("Codec", selection: Binding(get: { settings.codec }, set: { act(.settings(settings.choosing(codec: $0))) })) {
                        ForEach(HaloRenderSettings.codecs, id: \.self) { codec in
                            Text(HaloRenderSettings.codecTitle(codec))
                                .tag(codec)
                                .disabled(HaloRenderSettings.codecRefusal(codec) != nil && codec != settings.codec)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                    .disabled(!editing)
                    .help(Self.codecHelp(busy: busyHelp) ?? "")
                    .haloControl(id: "halo.render.codec", enabled: editing, help: busyHelp)
                }
            }
            Toggle(
                "Transparent background",
                isOn: Binding(get: { settings.alpha }, set: { act(.settings(settings.choosing(alpha: $0))) })
            )
            .toggleStyle(.checkbox)
            .disabled(alphaHelp != nil)
            .help(alphaHelp ?? "")
            .haloControl(id: "halo.render.alpha", enabled: alphaHelp == nil, help: alphaHelp)
        }
    }
}
