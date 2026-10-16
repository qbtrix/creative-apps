// FakeRoundTrips.swift: the in-memory RoundTripEditing (UC-6). Begin refuses
// a photo whose original is gone with `originalMissing`; Photo's save and
// Library's return move the session along. With `unavailable:` set, every
// throwing call throws `.notAvailable(that sentence)`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public actor FakeRoundTrips: RoundTripEditing {
    public private(set) var sessions: [String: RoundTripSession] = [:]
    let unavailable: String?
    let missingOriginals: Set<String>   // fileIDs whose original is gone
    public init(missingOriginals: Set<String> = [], unavailable: String? = nil) {
        self.missingOriginals = missingOriginals; self.unavailable = unavailable
    }

    public func begin(_ source: RoundTripSource, id: String, at date: Date) throws(SuiteError) -> RoundTripSession {
        if let unavailable { throw .notAvailable(unavailable) }
        let name = source.original.displayName
        let base = name.split(separator: ".").first.map(String.init) ?? name
        if missingOriginals.contains(source.original.fileID) { throw .originalMissing(name: base) }
        let s = RoundTripSession(id: id, source: source, title: "\(base) (Library edit)", state: .open, startedAt: date)
        sessions[id] = s
        return s
    }

    public func photoSaved(session id: String, flattened: SuiteDocumentRef, layered: SuiteDocumentRef) throws(SuiteError) -> RoundTripSession {
        if let unavailable { throw .notAvailable(unavailable) }
        guard var s = sessions[id], s.state == .open || isSaved(s.state) else {
            throw .notAvailable("This edit is no longer open in Library.")
        }
        s.state = .saved(flattened: flattened, layered: layered)
        sessions[id] = s
        return s
    }

    public func returned(session id: String, as ref: SuiteDocumentRef) throws(SuiteError) -> RoundTripSession {
        if let unavailable { throw .notAvailable(unavailable) }
        guard var s = sessions[id], isSaved(s.state) else { throw .notAvailable("Nothing to bring back yet.") }
        s.state = .returned(ref)
        sessions[id] = s
        return s
    }

    public func cancel(session id: String) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        guard var s = sessions[id] else { return }
        s.state = .cancelled
        sessions[id] = s
    }

    public func session(_ id: String) -> RoundTripSession? { sessions[id] }

    func isSaved(_ state: RoundTripState) -> Bool { if case .saved = state { return true }; return false }
}
