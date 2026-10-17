// FakeAnimationSource.swift: the in-memory AnimationSourceReading (UC-10).
// Summaries are keyed by fileID; an unknown file is `fileMissing`. With
// `unavailable:` set, `summary` throws `.notAvailable(that sentence)`.

public struct FakeAnimationSource: AnimationSourceReading {
    public var summaries: [String: AnimationSummary]   // keyed by fileID
    let unavailable: String?
    public init(summaries: [String: AnimationSummary] = [:], unavailable: String? = nil) {
        self.summaries = summaries; self.unavailable = unavailable
    }
    public func summary(of ref: SuiteDocumentRef) throws(SuiteError) -> AnimationSummary {
        if let unavailable { throw .notAvailable(unavailable) }
        guard let s = summaries[ref.fileID] else { throw .fileMissing(name: ref.displayName) }
        return s
    }
}
