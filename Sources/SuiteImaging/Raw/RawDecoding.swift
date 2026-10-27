// RawDecoding.swift: the seam `FakeRawDecoder` and `SystemRawDecoder` share
// (shared-raw SR-2). `SuiteRaw` plans a request and calls one of these three;
// a decoder never applies exposure or white balance of its own (the shared
// tone sliders are their one home). Linux-safe.
import CoreRaster

public protocol RawDecoding: Sendable {
    func info(_ source: RawSource) throws(RawRefusal) -> RawFileInfo
    func embeddedPreview(_ source: RawSource, longestSide: Int) throws(RawRefusal) -> PixelBuffer
    /// Linear, tone curve off, baseline exposure 0, as-shot white balance, highlight recovery where supported.
    func develop(_ source: RawSource, scale: Double, draft: Bool) throws(RawRefusal) -> PixelBuffer
}
