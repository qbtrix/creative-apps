// SuiteOnboarding.swift: the live OnboardingFlowing (UC-13, blueprint 5.2
// row 13). The pages and the focus → order rule are the fake's (one rule for
// the window and the home); `shouldShow` is `(done ?? 0) < version`, so a
// bumped version shows the tour again (onboarding OB-7). Foundation free,
// Linux-safe, Sendable.

/// The live OnboardingFlowing (blueprint 5.2 row 13: "same type in Onboarding/").
public struct SuiteOnboarding: OnboardingFlowing {
    public static let version = 1
    /// The one line about rendering on page 1.
    public static let renderingNote = "Rendering is Automatic, which draws on the CPU in this beta. View > Rendering in any app changes it."
    public init() {}
    public var pages: [OnboardingPage] { FakeOnboarding().pages }
    /// True until this version has been finished or skipped; a newer version shows again.
    public func shouldShow(_ p: SuitePreferences, version: Int) -> Bool { (p.onboardingDoneVersion ?? 0) < version }
    /// Records `version` as done and puts the focus's apps first, keeping every other field.
    public func finishing(_ p: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences {
        FakeOnboarding().finishing(p, focus: focus, version: version)
    }
    /// True when the preset asks for more (a size, a folder) before it acts: its title ends in "…".
    public static func asksForMore(_ preset: NewDocumentPreset) -> Bool { preset.title.hasSuffix("…") }
    /// A preset chip's label on the start page. A preset that asks for more keeps its own title,
    /// ellipsis and all ("Import Folder…", HIG); a one-step one names the document it makes ("New Blank Design").
    public static func presetTitle(_ preset: NewDocumentPreset) -> String {
        if asksForMore(preset) || preset.title.hasPrefix("New ") || preset.title.hasPrefix("Import ") { return preset.title }
        let tileTitle = SuiteCreating.titles[preset.app] ?? ""
        let noun = tileTitle.hasPrefix("New ") ? String(tileTitle.dropFirst(4)) : "Document"
        return "New " + preset.title + " " + noun
    }
    /// A tile's chips' help: what a click does, saying so when a chip asks for more first.
    public static func presetsHelp(_ tile: NewTile) -> String {
        let shown = tile.presets.prefix(3), name = tile.app.displayName
        if !shown.isEmpty, shown.allSatisfy(asksForMore) { return "Opens \(name), which asks for the details before it starts." }
        if shown.contains(where: asksForMore) { return "Creates a new \(name) document; a chip ending in … asks for details first." }
        return "Creates a new \(name) document and closes this window."
    }
    /// A focus chip's label: the focus and the apps it puts first, in order ("Animation: Flare, Halo");
    /// just the focus when it names its one app ("Design") or moves none ("Everything").
    public static func focusTitle(_ focus: OnboardingFocus) -> String {
        let name = focus == .motion ? "Motion graphics" : focus.rawValue.capitalized
        let apps = FakeOnboarding.firstApps(for: focus).map(\.displayName)
        return apps.isEmpty || apps == [name] ? name : name + ": " + apps.joined(separator: ", ")
    }
    /// The apps a focus puts first, the order the start page and the home share.
    public static func order(for focus: OnboardingFocus?) -> [SuiteApp] {
        SuiteOnboarding().finishing(SuitePreferences(), focus: focus, version: version).homeOrder
    }
}
