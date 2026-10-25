// CrashFolderReader.swift (report-problem RP-5b): this Mac's crash files for Report a Problem. Lists
// CrashFolder's folder once, opens only the entries CrashFolder.toRead keeps, and reads each as UTF-8 text.
// A folder or file it can't read gives nothing, never an error: the report then says it has no crashes.
// Reads the disk only; no network.
import Foundation
import SuiteModel

/// Reads the crash files a problem report may show.
public enum CrashFolderReader {
    /// The recent `.ips` files in the crash folder `arguments` and `home` name, newest first.
    public static func read(arguments: [String] = ProcessInfo.processInfo.arguments, home: String = NSHomeDirectory(),
                            now: Date = Date()) -> [CrashFile] {
        let folder = URL(fileURLWithPath: CrashFolder.path(arguments: arguments, home: home), isDirectory: true)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return [] }
        var byName: [String: URL] = [:]
        let entries = urls.compactMap { url -> CrashFolder.Entry? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                  let modified = values.contentModificationDate else { return nil }
            byName[url.lastPathComponent] = url
            return CrashFolder.Entry(name: url.lastPathComponent, modified: modified)
        }
        return CrashFolder.toRead(entries, now: now).compactMap { entry in
            guard let url = byName[entry.name], let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return CrashFile(name: entry.name, modified: entry.modified, text: text)
        }
    }
}
