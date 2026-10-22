// MetadataCarrying.swift: export-pack XP-2. Copies a source image's metadata
// onto a freshly encoded still, minus the property paths an export's policy
// drops (`ExportRules.dropped`). Live: SuiteShell's Media/StillMetadata.swift
// (XP-7) on ImageIO. Foundation only for `Data`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Carries metadata from a source image onto an encoded still.
public protocol MetadataCarrying: Sendable {
    /// `still` (encoded bytes) rewritten with `source`'s metadata minus `dropping`; orientation and the colour
    /// profile always kept. An unreadable source copies nothing.
    func carrying(_ still: Data, from source: Data, dropping: Set<String>) throws(SuiteError) -> Data
    /// The property paths present in an image: what tests and jobs assert on.
    func properties(of image: Data) throws(SuiteError) -> Set<String>
}
