// LauncherRouter+Onboarding.swift: what the welcome window's Open sample
// reads and writes (onboarding packet OB-12): the bundle's samples
// (Resources/Samples, which bundle-apps copies Bundle/Samples/ to), the
// support folder's Documents, and a FileManager copy that makes the
// destination's folder first and never overwrites (SampleCatalog.destination
// picks a free name; copyItem refuses an existing one).
import Foundation
import SuiteModel

extension LauncherServices {
    /// The bundle's samples: <Resources>/Samples.
    static let samplesFolder = SampleCatalog.folder(resources: Bundle.main.resourcePath ?? "")

    /// The support folder's Documents, where a sample's copy lands under Samples/.
    static func documents(support: String) -> String { support + "/Documents" }

    /// Copies `source` to `destination`, making its folder first; a failure is ioFailed with the file's name.
    static func copySample(_ source: String, to destination: String) throws(SuiteError) {
        let files = FileManager.default
        let folder = (destination as NSString).deletingLastPathComponent
        do {
            try files.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try files.copyItem(atPath: source, toPath: destination)
        } catch {
            throw .ioFailed((destination as NSString).lastPathComponent)
        }
    }
}
