// CrashFolderReader.swift (report-problem RP-5b): this machine's crash files for Report a Problem, shared by the
// sheet (ShellHelpProvider) and the CLI (HelpReports), so both read the same files. Lists CrashFolder's folder
// once, opens only the entries CrashFolder.toRead keeps, and reads each as UTF-8 text. A folder or file it can't
// read gives nothing, never an error: the report then says it has no crashes. Reads the disk only; no network.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Reads the crash files a problem report may show.
public enum CrashFolderReader {
    /// The recent suite crash files in the crash folder `arguments` and `home` name, newest first.
    public static func read(arguments: [String], home: String, now: Date) -> [CrashFile] {
        read(folder: CrashFolder.path(arguments: arguments, home: home), now: now)
    }

    /// The recent suite crash files in `folder`, newest first.
    public static func read(folder: String, now: Date) -> [CrashFile] {
        let files = FileManager.default
        guard let names = try? files.contentsOfDirectory(atPath: folder) else { return [] }
        let base = folder.hasSuffix("/") ? folder : folder + "/"
        let entries = names.compactMap { name -> CrashFolder.Entry? in
            // Only a crash file's attributes are read: a folder of thousands of other logs costs one listing.
            guard CrashFolder.isCrash(name), !name.hasPrefix("."),
                  let attributes = try? files.attributesOfItem(atPath: base + name),
                  attributes[.type] as? FileAttributeType == .typeRegular,
                  let modified = attributes[.modificationDate] as? Date else { return nil }
            return CrashFolder.Entry(name: name, modified: modified)
        }
        return CrashFolder.toRead(entries, now: now).compactMap { entry in
            guard let data = files.contents(atPath: base + entry.name) else { return nil }
            return CrashFile(name: entry.name, modified: entry.modified, text: String(decoding: data, as: UTF8.self))
        }
    }
}
