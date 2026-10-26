// CarriedMetadata.swift: export-pack LX-4, the export writer's metadata step
// on SuiteModel's `MetadataCarrying` (an adapter, rule 20: the copy itself is
// the suite's, `services.metadata`). `still` hands the carrier the encoded
// still, the original file's bytes and the properties the policy drops
// (`ExportRules.dropped(policy).properties`, carried on each plan item). No
// source, an unreadable or empty one, or a carrier that can't act leaves the
// still as encoded: nothing is copied, so nothing the policy drops can leak.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

public enum CarriedMetadata {
    /// `still` with the metadata of the file at `source` minus `dropping`, through `carrier`; `read` loads the
    /// original's bytes (the file on disk by default, nil when it can't be read).
    public static func still(_ still: Data, from source: String?, dropping: Set<String>, carrier: any MetadataCarrying,
                             read: (String) -> Data? = { try? Data(contentsOf: URL(fileURLWithPath: $0)) }) -> Data {
        guard let source, let original = read(source), !original.isEmpty else { return still }
        do {
            return try carrier.carrying(still, from: original, dropping: dropping)
        } catch {
            return still
        }
    }
}
