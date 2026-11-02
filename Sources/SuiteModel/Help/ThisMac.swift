// ThisMac.swift (report-problem): the machine values a problem report names, read the same way by the sheet
// (ShellHelpProvider) and the CLI (HelpReports): the running bundle's version and build, macOS, the Mac model,
// and the home, user and host names the report redacts. Reads no network: the host name comes from gethostname,
// never ProcessInfo.hostName, which raises macOS's local network prompt. Off a Mac, version, build and model are
// empty and the report leaves them out.
#if canImport(Darwin)
import Darwin
import Foundation
#else
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#endif
#endif

/// This machine's values for a problem report.
public enum ThisMac {
    /// The running bundle's version ("0.9.0"), the enclosing AfterGlow.app's for the CLI, or "" outside one.
    public static var version: String { info("CFBundleShortVersionString") }
    /// The running bundle's build ("412"), or "" outside a bundle.
    public static var build: String { info("CFBundleVersion") }
    /// The macOS version as the system words it ("Version 26.1 (Build 25B78)").
    public static var macOS: String { ProcessInfo.processInfo.operatingSystemVersionString }

    /// The home folder: `HOME`, else the user's home from the system.
    public static var home: String {
        #if canImport(Darwin)
        NSHomeDirectory()
        #else
        ProcessInfo.processInfo.environment["HOME"] ?? ""
        #endif
    }

    /// The login name.
    public static var user: String {
        #if canImport(Darwin)
        NSUserName()
        #else
        ProcessInfo.processInfo.environment["USER"] ?? ""
        #endif
    }

    /// The host name from the kernel; "" when it can't be read.
    public static var host: String {
        var bytes = [CChar](repeating: 0, count: 256)
        guard gethostname(&bytes, bytes.count) == 0 else { return "" }
        return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// The Mac's model identifier ("Mac15,3"), or "" when sysctl can't read it or this isn't a Mac.
    public static var model: String {
        #if canImport(Darwin)
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &bytes, &size, nil, 0) == 0 else { return "" }
        return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        #else
        ""
        #endif
    }

    private static func info(_ key: String) -> String {
        #if canImport(Darwin)
        if let value = Bundle.main.infoDictionary?[key] as? String { return value }
        // The CLI sits in AfterGlow.app/Contents/Helpers, where Bundle.main isn't the app: read the enclosing .app's.
        let path = Bundle.main.executablePath ?? ""
        guard let app = path.range(of: ".app/", options: .backwards) else { return "" }
        return Bundle(path: String(path[..<app.lowerBound]) + ".app")?.infoDictionary?[key] as? String ?? ""
        #else
        ""
        #endif
    }
}
