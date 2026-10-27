// Journey+Live.swift (editor-menus, #4808): an `afterglow` client for a journey. `grantLive` seeds a granted
// client in the support folder a journey passes as `-SuiteSupportDir` (preferences.json, FileStore's
// {"revision", "value"} envelope; AIAccessGrants' `perApp[<app>]["aiAccess.<client>"] = "alwaysForClient"`), so
// the app runs the call with no approval sheet. `runLive` sends one `live/run` to the app's newest socket in
// ~/Library/Application Support/AfterGlow/live (`<app>-<pid>.sock`, LiveCommandChannel) and returns its reply.
import Foundation
import XCTest

enum JourneyLive {
    /// The client name a journey's calls carry.
    static let client = "journey"

    /// Writes preferences.json into `support` with `client` always allowed in `app` (a SuiteApp raw value).
    static func grant(_ app: String, in support: URL) throws {
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let value: [String: Any] = [
            "revision": 0, "units": "points", "autosaveSeconds": 30, "checkForUpdates": true,
            "homeOrder": ["flare", "design", "photo", "library", "halo"],
            "perApp": [app: ["aiAccess.\(client)": "alwaysForClient"]],
        ]
        let data = try JSONSerialization.data(withJSONObject: ["revision": 1, "value": value])
        try data.write(to: support.appending(path: "preferences.json"))
    }

    /// Runs command `id` with `params` in `app`'s live channel; the reply's `result` object, or a thrown reason.
    static func run(_ app: String, _ id: String, params: [String: Any]) throws -> [String: Any] {
        let path = try socket(of: app)
        let request: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": "live/run",
                                      "params": ["client": client, "id": id, "params": params]]
        var line = try JSONSerialization.data(withJSONObject: request)
        line.append(0x0A)
        let reply = try exchange(line, at: path)
        guard let object = try JSONSerialization.jsonObject(with: reply) as? [String: Any] else { throw LiveJourneyError("not a JSON object") }
        if let error = object["error"] { throw LiveJourneyError("\(id) answered \(error)") }
        guard let result = object["result"] as? [String: Any] else { throw LiveJourneyError("\(id) answered no result: \(object)") }
        return result
    }

    /// The newest `<app>-*.sock` in the live folder.
    static func socket(of app: String) throws -> String {
        let dir = NSHomeDirectory() + "/Library/Application Support/AfterGlow/live"
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [])
            .filter { $0.hasPrefix(app + "-") && $0.hasSuffix(".sock") }
        let dated = names.map { name -> (String, Date) in
            let date = (try? FileManager.default.attributesOfItem(atPath: dir + "/" + name))?[.modificationDate] as? Date
            return (dir + "/" + name, date ?? .distantPast)
        }
        guard let newest = dated.max(by: { $0.1 < $1.1 }) else { throw LiveJourneyError("no \(app) socket in \(dir)") }
        return newest.0
    }

    /// Connects to `path`, writes `line` and reads one reply line, waiting at most 15 s.
    static func exchange(_ line: Data, at path: String) throws -> Data {
        var address = sockaddr_un()
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw LiveJourneyError("socket path too long: \(path)") }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            for (i, byte) in bytes.enumerated() { raw[i] = byte }
        }
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw LiveJourneyError("no socket: errno \(errno)") }
        defer { close(fd) }
        var wait = timeval(tv_sec: 15, tv_usec: 0)
        _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &wait, socklen_t(MemoryLayout<timeval>.size))
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let joined = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, size) } }
        guard joined == 0 else { throw LiveJourneyError("can't connect to \(path): errno \(errno)") }
        let sent = line.withUnsafeBytes { write(fd, $0.baseAddress, line.count) }
        guard sent == line.count else { throw LiveJourneyError("wrote \(sent) of \(line.count) bytes") }
        var reply = Data(), chunk = [UInt8](repeating: 0, count: 4096)
        while !reply.contains(0x0A) {
            let got = read(fd, &chunk, chunk.count)
            guard got > 0 else { throw LiveJourneyError("no reply from \(path) (errno \(errno))") }
            reply.append(contentsOf: chunk[0..<got])
        }
        return reply.prefix { $0 != 0x0A }
    }

    /// The title of the Edit menu's Undo item, read with the menu open.
    @MainActor static func undoTitle(in journey: Journey) -> String {
        let edit = journey.app.menuBars.firstMatch.menuBarItems["Edit"]
        _ = edit.waitForExistence(timeout: 5)
        edit.click()
        let items = edit.menus.firstMatch.children(matching: .menuItem)
        _ = items.firstMatch.waitForExistence(timeout: 3)
        let undo = items.allElementsBoundByIndex.map(\.title).first { $0.hasPrefix("Undo") } ?? ""
        journey.press(.escape)
        return undo
    }
}

struct LiveJourneyError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
