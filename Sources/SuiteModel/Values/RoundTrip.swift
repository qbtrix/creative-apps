// RoundTrip.swift: a Library to Photo to Library edit session, where it
// came from and where it stands. Foundation only for `Date`, Linux-safe,
// Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The catalog photo a round trip edits.
public struct RoundTripSource: Codable, Equatable, Sendable {
    public var catalogPhotoID: String    // Library's photo id
    public var original: SuiteDocumentRef
    public init(catalogPhotoID: String, original: SuiteDocumentRef) {
        self.catalogPhotoID = catalogPhotoID; self.original = original
    }
}

/// Where a round trip stands.
public enum RoundTripState: Codable, Equatable, Sendable {
    case open                              // Photo has it
    case saved(flattened: SuiteDocumentRef, layered: SuiteDocumentRef)
    case returned(SuiteDocumentRef)        // in Library's catalog, stacked on the original
    case cancelled
    case failed(String)
}

/// One edit of a catalog photo in Photo, from begin to return.
public struct RoundTripSession: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var source: RoundTripSource
    public var title: String               // "IMG_0002 (Library edit)"
    public var state: RoundTripState
    public var startedAt: Date
    public init(id: String, source: RoundTripSource, title: String, state: RoundTripState, startedAt: Date) {
        self.id = id; self.source = source; self.title = title; self.state = state; self.startedAt = startedAt
    }
}
