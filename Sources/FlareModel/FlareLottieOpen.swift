// FlareLottieOpen: opens a Lottie JSON file as an untitled Flare document,
// plus one sentence for each part the reader had to leave out. This is the
// LO-a stub: the contract is fixed here, and LO-3 makes `open` read the file
// through FlareCore's LottieImport.

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// The document a Flare window edits.
public typealias FlareDocument = FlareCore.Document

/// Why a file could not be opened, each with the sentence the app shows.
public enum FlareOpenError: Error, Equatable, Sendable {
    /// The bytes are not a Lottie file at all.
    case notLottie
    /// The bytes look like Lottie but are broken; the string says where.
    case damaged(String)
    /// The file is over a reader limit; the string names the limit.
    case tooLarge(String)
    /// Opening this kind of file has not been built yet.
    case notYet

    public var message: String {
        switch self {
        case .notLottie: "This file isn't a Lottie file."
        case .damaged(let detail):
            FlareWorkspace.sentence("This file isn't a Lottie file Flare can read", detail)
        case .tooLarge(let detail):
            FlareWorkspace.sentence("This Lottie file is larger than Flare can open", detail)
        case .notYet: "Opening Lottie arrives with LO-3."
        }
    }
}

/// Opens Lottie JSON. Save never writes back to the JSON: the document opens
/// untitled, so the first Save asks for a .flare file.
public enum FlareLottieOpen {
    /// The file extensions the Open panel offers for Lottie.
    public static let fileExtensions = ["json"]

    /// The document and one sentence per skipped part, in file order.
    public static func open(
        data: Data, name: String
    ) throws(FlareOpenError) -> (FlareDocument, [String]) {
        throw .notYet
    }
}
