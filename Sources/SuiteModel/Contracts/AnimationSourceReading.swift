// AnimationSourceReading.swift: a suite contract from blueprint suite.md 5.2. Every throwing
// requirement throws `SuiteError`, whose `message` is the sentence the UI shows.

/// UC-10 Read a Flare animation for Halo (tier 3). Live: in HaloModel, which
/// already links FlareCore (SuiteModel never imports an engine).
public protocol AnimationSourceReading: Sendable {
    func summary(of ref: SuiteDocumentRef) async throws(SuiteError) -> AnimationSummary
}
