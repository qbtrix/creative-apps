// FakeThumbnails.swift: the in-memory ThumbnailPublishing (UC-15). Writes
// `thumbnails/<SuiteDocumentRef.fileKey(fileID)>.png` (packet correction 1:
// a file id has slashes, so it never names a file). With `unavailable:` set,
// `publish` throws `.notAvailable(that sentence)`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public actor FakeThumbnails: ThumbnailPublishing {
    public private(set) var written: [String: Data] = [:]
    let unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }
    public func publish(png: Data, for ref: SuiteDocumentRef) throws(SuiteError) -> String {
        if let unavailable { throw .notAvailable(unavailable) }
        let path = "thumbnails/\(SuiteDocumentRef.fileKey(ref.fileID)).png"
        written[path] = png
        return path
    }
}
