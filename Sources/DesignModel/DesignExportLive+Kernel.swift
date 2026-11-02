// DesignExportLive+Kernel.swift: the live export's loop and its lines (design-export DE-10,
// DE-11), so Linux tests and mutations reach them; the App's DesignExportArea renders and writes
// through it and feeds the outcome to the kernel's ExportRun. The loop writes the items in order:
// it checks Cancel before each item and again between its render and its write, so nothing is
// written after Cancel; it reports progress after each written file; the first render or write
// that throws stops the run and names that file. The finished line names the folder and up to
// three written files; the failed line adds how to fix it. Linux-safe.

/// How a live export ended: the files written, the file that failed and why, or a cancel.
public struct DesignExportOutcome: Sendable {
    public var written: [String] = []
    public var failed: (file: String, error: any Error)?
    public var cancelled = false
}

public enum DesignExportLive {
    /// Renders and writes `items` in order on the caller's actor (see the file header). Items and payloads
    /// are Sendable because the closures may run off that actor.
    public static func run<Item: Sendable, Payload: Sendable>(
        _ items: [Item], name: (Item) -> String,
        render: (Item) async throws -> Payload,
        write: (Payload, Item) async throws -> Void,
        isCancelled: () -> Bool = { Task.isCancelled },
        progressed: (Int) async -> Void,
        isolation: isolated (any Actor)? = #isolation
    ) async -> DesignExportOutcome {
        var outcome = DesignExportOutcome()
        for item in items {
            if isCancelled() { outcome.cancelled = true; break }
            do {
                let payload = try await render(item)
                if isCancelled() { outcome.cancelled = true; break }
                try await write(payload, item)
            } catch {
                outcome.failed = (name(item), error)
                break
            }
            outcome.written.append(name(item))
            await progressed(outcome.written.count)
        }
        return outcome
    }

    /// "Exported 1 file to Exports: Desktop 2.png.", "Exported 5 files to Out: A.png, B.png, C.png and 2 more."
    public static func finished(_ names: [String], folder: String) -> String {
        let count = "\(names.count) file\(names.count == 1 ? "" : "s")"
        let shown = Array(names.prefix(3))
        let rest = names.count - shown.count
        let list: String
        if rest > 0 {
            list = shown.joined(separator: ", ") + " and \(rest) more"
        } else if let last = shown.last, shown.count > 1 {
            list = shown.dropLast().joined(separator: ", ") + " and " + last
        } else {
            list = shown.first ?? ""
        }
        return "Exported \(count) to \(folder)" + (list.isEmpty ? "." : ": \(list).")
    }

    /// "<file> couldn't be written. <reason> Choose another folder and export again."
    public static func failed(_ file: String, reason: String) -> String {
        "\(file) couldn't be written. \(reason) Choose another folder and export again."
    }
}
