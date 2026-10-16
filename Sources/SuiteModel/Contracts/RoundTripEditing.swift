// RoundTripEditing.swift: a suite contract from blueprint suite.md 5.2. Every throwing
// requirement throws `SuiteError`, whose `message` is the sentence the UI shows.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-6 Library to Photo and back (tier 2). Live: a store over `roundtrips/`
/// and hand-offs; Library and Photo each call their half.
public protocol RoundTripEditing: Sendable {
    /// Library: start; Photo receives an `.edit` hand-off with the session id.
    func begin(_ source: RoundTripSource, id: String, at date: Date) async throws(SuiteError) -> RoundTripSession
    /// Photo: the person saved; the flattened copy is for Library, the layered one for re-editing.
    func photoSaved(session id: String, flattened: SuiteDocumentRef, layered: SuiteDocumentRef) async throws(SuiteError) -> RoundTripSession
    /// Library: the copy is in the catalog, stacked on the original.
    func returned(session id: String, as ref: SuiteDocumentRef) async throws(SuiteError) -> RoundTripSession
    func cancel(session id: String) async throws(SuiteError)
    func session(_ id: String) async -> RoundTripSession?
}
