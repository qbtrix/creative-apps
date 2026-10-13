// EditorTopBar.swift: the top bar of an EditorShell, after the Ripple editor's:
// the app name and the document name as a menu, then flat icon-and-label commands, a
// hairline between groups, and whatever trails (undo, zoom). Commands are
// ToolbarActions drawn by EditorBarItem (an action that can't run is disabled, its symbol dimmed,
// and its tooltip says why) or EditorBarMenu for a command that opens a menu.
// Both are native buttons and menus in the accessory-bar style: flat until
// hovered. The bar starts after the window's close, minimize and zoom buttons
// (the shell hides the title bar) and its empty stretches drag the window.
// Every command here must also be in the menu bar (docs/design.md, Commands).
import SwiftUI

public struct EditorTopBar<Menu: View, Content: View>: View {
    private let app: String
    private let document: String?
    private let menu: Menu
    private let content: Content

    /// The bar reads "`app` / `document`" and the document name opens `menu`;
    /// with no document open the app name opens it.
    public init(
        app: String, document: String?, @ViewBuilder menu: () -> Menu, @ViewBuilder content: () -> Content
    ) {
        self.app = app
        self.document = document
        self.menu = menu()
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            if let document {
                Text(app).font(SuiteFont.editorTitle)
                Text("/").foregroundStyle(SuiteColor.secondaryText)
                titleMenu(document, color: SuiteColor.accentText)
            } else {
                titleMenu(app, color: Color.primary)
            }
            EditorBarDivider()
            content
        }
        .font(SuiteFont.editorBar)
        .lineLimit(1)
        .padding(.leading, SuiteSize.windowControlsInset)
        .padding(.trailing, SuiteSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: SuiteSize.editorTopBar)
        .background {
            SuiteColor.panel
                .contentShape(.rect)
                .gesture(WindowDragGesture())
        }
    }
}

extension EditorTopBar {
    private func titleMenu(_ title: String, color: Color) -> some View {
        SwiftUI.Menu {
            menu
        } label: {
            HStack(spacing: SuiteSpacing.xs) {
                Text(title).font(SuiteFont.editorTitle).foregroundStyle(color)
                Image(systemName: "chevron.down").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.accessoryBar)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(title)
    }
}

/// One top bar command: its symbol and, unless `showsTitle` is false, its title.
public struct EditorBarItem: View {
    private let action: ToolbarAction
    private let showsTitle: Bool

    public init(_ action: ToolbarAction, showsTitle: Bool = true) {
        self.action = action
        self.showsTitle = showsTitle
    }

    public var body: some View {
        Button(action: action.perform) {
            Label(action.title, systemImage: action.systemImage)
                .labelStyle(EditorBarLabelStyle(showsTitle: showsTitle))
        }
        .buttonStyle(.accessoryBar)
        .disabled(!action.isEnabled)
        .help(action.help)
        .accessibilityLabel(action.title)
    }
}

/// A top bar command that opens a menu of `content`; disabled, saying why,
/// while `unavailableHelp` is set.
public struct EditorBarMenu<Content: View>: View {
    private let title: String
    private let systemImage: String
    private let unavailableHelp: String?
    private let content: Content

    public init(
        _ title: String, systemImage: String, unavailableHelp: String? = nil, @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.unavailableHelp = unavailableHelp
        self.content = content()
    }

    public var body: some View {
        Menu {
            content
        } label: {
            Label(title, systemImage: systemImage).labelStyle(EditorBarLabelStyle(showsTitle: true))
        }
        .menuStyle(.button)
        .buttonStyle(.accessoryBar)
        .menuIndicator(.hidden)
        .tint(SuiteColor.secondaryText)
        .fixedSize()
        .disabled(unavailableHelp != nil)
        .help(unavailableHelp ?? title)
        .accessibilityLabel(title)
    }
}

/// The hairline between top bar groups.
public struct EditorBarDivider: View {
    public init() {}

    public var body: some View {
        Divider().frame(height: SuiteSize.editorBarDivider).padding(.horizontal, SuiteSpacing.xs)
    }
}

/// Symbol then title, the symbol in the secondary color; or the symbol alone.
private struct EditorBarLabelStyle: LabelStyle {
    let showsTitle: Bool

    func makeBody(configuration: Configuration) -> some View {
        EditorBarLabel(configuration: configuration, showsTitle: showsTitle)
    }
}

/// The label EditorBarLabelStyle draws. Setting the symbol's color overrides the
/// system's disabled dimming, so a disabled command's symbol is tertiary here.
private struct EditorBarLabel: View {
    let configuration: LabelStyleConfiguration
    let showsTitle: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            configuration.icon.foregroundStyle(
                isEnabled ? AnyShapeStyle(SuiteColor.secondaryText) : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
            if showsTitle { configuration.title }
        }
    }
}
