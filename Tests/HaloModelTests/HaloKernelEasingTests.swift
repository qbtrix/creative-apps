// HaloKernelEasingTests.swift: AE-h1 of adopt-kernel-easing (#1937). Halo's presets are `EasePreset`, its handles
// `EaseCurve`, its keys and segments the kernel's `KeyRef` and `Segment`, and its key state, key diamond and
// stopwatch land where `KeyRules` puts them, with opacity's home and Halo's last-frame rule kept. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import HaloModel
import SuiteKernel
import Testing

private let curves: [HaloEasing] = EasePreset.allCases.map(\.easing) + [.cubicBezier(x1: 0.3, y1: -0.4, x2: 0.8, y2: 1.6)]

@Test func presetsAreTheKernels() {
    for preset in HaloEasingPreset.allCases {
        #expect(preset.kernel.rawValue == preset.rawValue && preset.easing == preset.kernel.easing)
        #expect(HaloEasingPreset(preset.kernel) == preset && HaloEasingPreset(preset.easing) == preset)
        #expect(preset.title == (preset == .easeInOut ? "Ease In and Out" : preset.kernel.title))
    }
    // Halo shows five of the kernel's six: `ease` is no Halo preset, so its curve reads as custom.
    #expect(HaloEasingPreset(EasePreset.ease) == nil && HaloEasingPreset(EasePreset.ease.easing) == nil)
}

@Test func handlesAndMovesAreTheKernels() {
    let point = HaloPoint(x: 1.4, y: -0.7)
    for easing in curves {
        let halo = easing.handles
        #expect([halo.first, halo.second] == EaseCurve.handles(of: easing) ?? [HaloPoint(x: 0, y: 0), HaloPoint(x: 1, y: 1)])
        #expect(easing.movingHandle(.first, to: point) == EaseCurve.moving(0, to: point, in: easing))
        #expect(easing.movingHandle(.second, to: point) == EaseCurve.moving(1, to: point, in: easing))
    }
}

@Test func keysAndSegmentsAreTheKernels() throws {
    let key = HaloKeyRef(layerID: "s", property: .rotation, frame: 12)
    #expect(key.kernel == KeyRef(layerID: "s", track: .property(.rotation), frame: 12) && HaloKeyRef(key.kernel) == key)
    #expect(HaloKeyRef(KeyRef<HaloProperty>(layerID: "s", track: .all, frame: 12)) == nil)
    let row = HaloKeySegment(key: key, endFrame: 24, easing: .easeIn, isPicked: true)
    #expect(row.segment == Segment(key: key.kernel, endFrame: 24, easing: .easeIn))
    #expect(HaloKeySegment(row.segment, isPicked: true) == row)
    // Saved files keep Halo's shape: a property, never the kernel's track.
    let json = try #require(String(data: try JSONEncoder().encode(key), encoding: .utf8))
    #expect(json.contains("\"property\":\"rotation\"") && !json.contains("track"))
    #expect(try JSONDecoder().decode(HaloKeyRef.self, from: Data(json.utf8)) == key)
}

@Test func keyStateIsTheKernels() {
    let tracks: [[HaloKeyframe]] = [[], [.init(frame: 0, value: 1)], [.init(frame: 0, value: 1), .init(frame: 9, value: 2)]]
    for track in tracks {
        for frame in [0, 5, 9] {
            #expect(HaloKeyRules.keyState(track, at: frame) == HaloKeyState(KeyRules.state(track, at: frame)))
        }
    }
    let animated = tracks[2]
    #expect([0, 5, 9].map { HaloKeyRules.keyState(animated, at: $0) } == [.keyedHere, .animated, .keyedHere])
    #expect(HaloKeyRules.keyState(tracks[1], at: 0) == .notAnimated)
}

@Test(arguments: propertyKeyings)
func theDiamondRemovesToTheKeyThatStays(keying: any PropertyKeying) throws {
    var comp = keyedPair()
    try keying.toggleKey(.x, of: "s", at: 15, in: &comp)
    var kernel = keyedPair().layers[1].tracks["x"] ?? []
    #expect(KeyRules.toggleKey(&kernel, at: 15, value: 100, leaving: .propertyGoesStatic))
    #expect(comp.layers[1].tracks["x"] == kernel)
    try keying.toggleKey(.x, of: "s", at: 15, in: &comp)
    try keying.toggleKey(.x, of: "s", at: 30, in: &comp)
    // The kernel empties a track left with one key; Halo keeps the key that stays as the static value.
    #expect(comp.layers[1].tracks["x"] == [HaloKeyframe(frame: 0, value: 50)])
}

@Test(arguments: propertyKeyings)
func theStopwatchOnAOneFrameCompositionKeysFrameZero(keying: any PropertyKeying) throws {
    var comp = keyedPair()
    comp.durationFrames = 1
    comp.layers[1].opacity = 0.5
    // The kernel refuses to animate when the playhead is the last frame and the other key would be too.
    var kernel: [HaloKeyframe] = []
    #expect(!KeyRules.toggleAnimated(&kernel, at: 0, lastFrame: 0, value: 0.5) && kernel.isEmpty)
    try keying.toggleAnimation(.opacity, of: "s", at: 0, in: &comp)
    #expect(comp.layers[1].tracks["opacity"] == [HaloKeyframe(frame: 0, value: 0.5)])
}
