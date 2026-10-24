// SuiteFilePanels.swift: the suite's one copy of the file panels (#5081). Every Open, Save and folder panel in
// every app and the home is built here and nowhere else (SuiteFilePanelsTests fails on another `NSOpenPanel(`).
// It lives in SuiteUI, not SuiteShell, because SuiteUI's PlacePanel needs it and SuiteShell depends on SuiteUI.
// Open types come from SuiteTypeRegistry (and so SuiteImageFormats) for the app; a panel starts in the folder the
// app's last panel chose, unless the caller names one; prompts default to Open, Save and Choose and the title
// matches the prompt. Two seams stand in for the panel: `answer` for in-process tests, and the
// `-SuiteFilePanelAnswer <path>` launch argument for journeys and headless runs ("" answers Cancel). The apps
// aren't sandboxed, so a chosen URL is used as it is, with no security-scoped bookmark.
import AppKit
import SuiteModel
import UniformTypeIdentifiers

@MainActor public enum SuiteFilePanels {
    public enum Kind: Equatable, Sendable { case open, save, folder }

    /// What a panel asks for: what the seam sees in place of a panel.
    public struct Request: Equatable, Sendable {
        public var kind: Kind
        public var types: [UTType] = []
        public var multiple = false
        public var name: String?
        public var prompt: String
        /// The folder the panel opens in: the caller's, else the last one chosen, else the system's.
        public var directory: URL?
    }

    /// Answers every request in place of a panel while set: the chosen URLs, nil for Cancel. Tests set it.
    public static var answer: ((Request) -> [URL]?)?
    /// Where the last chosen folder is kept; each app is its own process, so its own defaults domain.
    public static var defaults = UserDefaults.standard
    nonisolated static let lastDirectoryKey = "SuiteFilePanelLastDirectory"
    nonisolated static let launchKey = "SuiteFilePanelAnswer"

    /// Every type the registry says `app` opens, then `extensions` (Flare's Lottie JSON), once each.
    public nonisolated static func openTypes(for app: SuiteApp, adding extensions: [String] = []) -> [UTType] {
        let listed = SuiteTypeRegistry.standard.types.filter { $0.readers.contains(app) }.flatMap(\.extensions)
        var seen = Set<UTType>()
        return (listed + extensions).compactMap { UTType(filenameExtension: $0) }.filter { seen.insert($0).inserted }
    }

    /// A save panel's starting name: `base`, or "Untitled", ending in `.ext` once.
    public nonisolated static func fileName(_ base: String?, extension ext: String) -> String {
        let name = base.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled"
        return name.lowercased().hasSuffix("." + ext.lowercased()) ? name : name + "." + ext
    }

    /// The Open panel for files of `types` (any file when empty); none when cancelled.
    public static func chooseFiles(types: [UTType], multiple: Bool, prompt: String = "Open", directory: URL? = nil) -> [URL] {
        run(Request(kind: .open, types: types, multiple: multiple, prompt: prompt, directory: directory)) ?? []
    }

    /// The Open panel for one file of `types`; nil when cancelled.
    public static func chooseFile(types: [UTType], prompt: String = "Open", directory: URL? = nil) -> URL? {
        chooseFiles(types: types, multiple: false, prompt: prompt, directory: directory).first
    }

    /// The Save panel, starting at `name`, with an optional accessory (export options); nil when cancelled.
    public static func chooseSaveURL(named name: String, types: [UTType], prompt: String = "Save",
                                     accessory: NSView? = nil) -> URL? {
        run(Request(kind: .save, types: types, name: name, prompt: prompt), accessory: accessory)?.first
    }

    /// The folder panel, which can make a new folder, with an optional accessory (import options); nil when cancelled.
    public static func chooseFolder(prompt: String = "Choose", directory: URL? = nil, accessory: NSView? = nil) -> URL? {
        run(Request(kind: .folder, prompt: prompt, directory: directory), accessory: accessory)?.first
    }

    /// The launch argument's answer: its path, none for "" (Cancel), nil without the argument.
    nonisolated static func launchAnswer(_ defaults: UserDefaults) -> [URL]? {
        guard let path = defaults.string(forKey: launchKey) else { return nil }
        return path.isEmpty ? [] : [URL(fileURLWithPath: path)]
    }

    private static func run(_ request: Request, accessory: NSView? = nil) -> [URL]? {
        var request = request
        request.directory = request.directory ?? defaults.url(forKey: lastDirectoryKey)
        let urls: [URL]?
        if let answer {
            urls = answer(request)
        } else if let launched = launchAnswer(.standard) {
            urls = launched.isEmpty ? nil : launched
        } else {
            urls = show(request, accessory: accessory)
        }
        if let first = urls?.first {
            defaults.set(request.kind == .folder ? first : first.deletingLastPathComponent(), forKey: lastDirectoryKey)
        }
        return urls
    }

    private static func show(_ request: Request, accessory: NSView?) -> [URL]? {
        let panel: NSSavePanel
        if request.kind == .save {
            panel = NSSavePanel()
            panel.nameFieldStringValue = request.name ?? ""
            panel.accessoryView = accessory
        } else {
            let open = NSOpenPanel()
            open.canChooseFiles = request.kind == .open
            open.canChooseDirectories = request.kind == .folder
            open.allowsMultipleSelection = request.multiple
            open.accessoryView = accessory
            open.isAccessoryViewDisclosed = accessory != nil
            panel = open
        }
        if !request.types.isEmpty { panel.allowedContentTypes = request.types }
        panel.canCreateDirectories = true
        panel.prompt = request.prompt
        panel.title = request.prompt
        panel.directoryURL = request.directory
        guard panel.runModal() == .OK else { return nil }
        return (panel as? NSOpenPanel)?.urls ?? panel.url.map { [$0] }
    }
}
