// RealJobs.swift (afterglow-cli CL-2 stub, CL-9 body): the real-jobs
// harness. A real job is a folder `Tests/RealJobs/<app>/<job>/` holding one
// `*.jobs.json` with an `expect` block. `check` skips a job not meant for
// this platform with "macOS-only: <why>" (or "Linux-only: <why>") before it
// runs, then runs the script through ScriptRunner (forcing, so a rerun
// replaces its outputs) and compares each expected output: sha256 on the
// whole digest, JSON parsed and compared equal (where the expected JSON holds
// `{"$linux": v}`, the value must be v on Linux and any finite number on macOS:
// a text box the macOS CLI measures with Core Text, which Linux only
// estimates), or pixels within a tolerance. Pixels need a PNG decoder (creative-core image-codecs), not in
// yet, so a job whose other expectations hold but that expects pixels is
// skipped "waits on image-codecs", never passed. Files are reached only
// through CLIIO; the runner's own report is captured, so one JSON object
// prints. SHA-256 is written here (FIPS 180-4): neither the repo nor
// creative-core has one that builds on Linux without a new dependency.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

/// Runs real jobs and checks their outputs against their expectations.
public enum RealJobs {
    /// The slice that builds the harness.
    public static let slice = "CL-jobs"

    /// Why a pixel expectation is skipped until a PNG decoder reaches the apps.
    static let pixelsWait = "waits on image-codecs (qbtrix/creative-core#562): pixels can't be decoded yet"

    /// Runs the job in the folder `job` among `apps` and prints one JSON report: `"ok": true` when every
    /// expectation held (exit 0), `"ok": false` with each failing output's path and why (exit 70, or the
    /// runner's code when the run itself failed), or `"skipped": "<reason>"` (exit 0) for a job not meant
    /// for this platform or one waiting on pixels. Returns the exit code.
    public static func check(_ job: String, apps: [HeadlessApp], io: any CLIIO) -> Int32 {
        let scripts = (try? io.glob("*.jobs.json", relativeTo: job)) ?? []
        guard scripts.count == 1, let script = scripts.first else {
            return fail(job, [Failure(path: job, why: "holds \(scripts.count) *.jobs.json files, not one")], io: io)
        }
        guard let data = try? io.read(script), case .object(let fields)? = try? JSONValue(json: data),
              case .object(let expect)? = fields["expect"], !expect.isEmpty else {
            return fail(job, [Failure(path: script, why: "is not a script with an expect block")], io: io)
        }
        if let reason = platformSkip(fields) { return report(Report(job: job, skipped: reason), io: io) }
        let capture = CaptureIO(io)
        let code = ScriptRunner.run(script, apps: apps, dryRun: false, force: true, io: capture)
        guard code == CLI.Exit.ok else {
            let why = "the run exited \(code): \(capture.printed.joined(separator: " "))"
            return fail(job, [Failure(path: script, why: why)], code: code, io: io)
        }
        var failures: [Failure] = [], waiting = false
        for (path, want) in expect.sorted(by: { $0.key < $1.key }) {
            switch verdict(want, output: job + "/" + path, io: io) {
            case .pass: continue
            case .skip: waiting = true
            case .fail(let why): failures.append(Failure(path: path, why: why))
            }
        }
        if !failures.isEmpty { return fail(job, failures, io: io) }
        if waiting { return report(Report(job: job, skipped: pixelsWait), io: io) }
        return report(Report(ok: true, job: job, checked: expect.keys.sorted()), io: io)
    }

    /// The skip reason for a job whose `platforms` leaves this one out, from its `why`; nil when it runs here.
    static func platformSkip(_ fields: [String: JSONValue]) -> String? {
        #if os(Linux)
        let here = "linux", only = "macOS-only"
        #else
        let here = "macos", only = "Linux-only"
        #endif
        guard case .array(let platforms)? = fields["platforms"], !platforms.contains(.string(here)) else { return nil }
        let why = if case .string(let text)? = fields["why"] { text } else { "the job names no why" }
        return "\(only): \(why)"
    }

    /// What one expectation says about its output.
    enum Verdict: Equatable { case pass, skip, fail(String) }

    /// Checks the file at `output` against `want`: `{"sha256": hex}`, `{"json": value}` or `{"pixels": …}`.
    static func verdict(_ want: JSONValue, output: String, io: any CLIIO) -> Verdict {
        guard case .object(let kinds) = want, kinds.count == 1, let (kind, value) = kinds.first else {
            return .fail("expects one of sha256, json or pixels")
        }
        guard let data = try? io.read(output) else { return .fail("was not written") }
        switch (kind, value) {
        case ("sha256", .string(let hex)):
            let digest = sha256Hex(data)
            return digest == hex.lowercased() ? .pass : .fail("sha256 is \(digest), expected \(hex)")
        case ("json", let expected):
            guard let got = try? JSONValue(json: data) else { return .fail("is not JSON") }
            return matches(got, expected) ? .pass : .fail("JSON differs from the expected value")
        case ("pixels", .object):
            return .skip
        default:
            return .fail("has an unknown or malformed expectation \(kind)")
        }
    }

    /// Whether `got` equals `want`, where a `{"$linux": v}` in `want` is v on Linux and any finite number elsewhere.
    public static func matches(_ got: JSONValue, _ want: JSONValue) -> Bool {
        switch (got, want) {
        case (_, .object(let w)) where w.count == 1 && w["$linux"] != nil:
            #if os(Linux)
            return got == w["$linux"]
            #else
            if case .number(let n) = got { return n.isFinite }
            return false
            #endif
        case (.object(let g), .object(let w)):
            return g.count == w.count && w.allSatisfy { key, value in g[key].map { matches($0, value) } ?? false }
        case (.array(let g), .array(let w)):
            return g.count == w.count && zip(g, w).allSatisfy { matches($0, $1) }
        default:
            return got == want
        }
    }

    /// Whether two RGBA8 images match: the same size, and every channel within `tolerance` (in 255ths).
    /// What a pixel expectation will compare once CoreRaster can decode PNG.
    public static func pixelsMatch(_ got: [UInt8], _ want: [UInt8], tolerance: Int) -> Bool {
        got.count == want.count && zip(got, want).allSatisfy { abs(Int($0) - Int($1)) <= tolerance }
    }

    /// One output that didn't meet its expectation.
    struct Failure: Encodable { let path: String; let why: String }

    /// What `check` prints. `ok` is absent on a skip: a skipped job is neither passed nor failed.
    struct Report: Encodable {
        var ok: Bool?; let job: String; var checked: [String]?; var failures: [Failure]?; var skipped: String?
    }

    static func fail(_ job: String, _ failures: [Failure], code: Int32 = CLI.Exit.failed, io: any CLIIO) -> Int32 {
        io.out(CLI.encode(Report(ok: false, job: job, failures: failures)))
        io.err(failures.map { "real job \(job): \($0.path) \($0.why)" }.joined(separator: "; "))
        return code
    }

    static func report(_ report: Report, io: any CLIIO) -> Int32 {
        io.out(CLI.encode(report))
        return CLI.Exit.ok
    }

    /// The lowercase hex SHA-256 digest of `data` (FIPS 180-4).
    public static func sha256Hex(_ data: Data) -> String {
        var hash: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
        var bytes = [UInt8](data)
        let bits = UInt64(bytes.count) &* 8
        bytes.append(0x80)
        while bytes.count % 64 != 56 { bytes.append(0) }
        bytes += (0..<8).reversed().map { UInt8(truncatingIfNeeded: bits >> (UInt64($0) * 8)) }
        var w = [UInt32](repeating: 0, count: 64)
        for start in stride(from: 0, to: bytes.count, by: 64) {
            for i in 0..<16 {
                w[i] = bytes[start + 4 * i ..< start + 4 * i + 4].reduce(0) { $0 << 8 | UInt32($1) }
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }
            var (a, b, c, d, e, f, g, h) = (hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7])
            for i in 0..<64 {
                let t1 = h &+ (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) &+ ((e & f) ^ (~e & g)) &+ roundK[i] &+ w[i]
                let t2 = (rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) &+ ((a & b) ^ (a & c) ^ (b & c))
                (h, g, f, e, d, c, b, a) = (g, f, e, d &+ t1, c, b, a, t1 &+ t2)
            }
            for (i, v) in [a, b, c, d, e, f, g, h].enumerated() { hash[i] = hash[i] &+ v }
        }
        return hash.map { word in
            let hex = String(word, radix: 16)
            return String(repeating: "0", count: 8 - hex.count) + hex
        }.joined()
    }

    static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 { x >> n | x << (32 - n) }

    /// The 64 SHA-256 round constants.
    static let roundK: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]
}

/// The caller's files, with whatever the runner prints kept back so `check` prints one report.
final class CaptureIO: CLIIO {
    private let base: any CLIIO
    private let lines = Mutex<[String]>([])
    init(_ base: any CLIIO) { self.base = base }

    /// Everything the runner printed, stdout and stderr in order.
    var printed: [String] { lines.withLock { $0 } }

    func read(_ path: String) throws -> Data { try base.read(path) }
    func write(_ data: Data, to path: String, replace: Bool) throws { try base.write(data, to: path, replace: replace) }
    func exists(_ path: String) -> Bool { base.exists(path) }
    func glob(_ pattern: String, relativeTo dir: String) throws -> [String] { try base.glob(pattern, relativeTo: dir) }
    func out(_ line: String) { lines.withLock { $0.append(line) } }
    func err(_ line: String) { lines.withLock { $0.append(line) } }
}
