// SidebarRow.swift: SidebarItem (id, title, SF Symbol, optional count) and the
// row SuiteWindow draws for it. Row height follows the system sidebar size
// setting, so nothing here fixes a height.
import SwiftUI

public struct SidebarItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    /// A count shown as a trailing badge; nil or 0 shows none.
    public let count: Int?

    public init(id: String, title: String, systemImage: String, count: Int? = nil) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.count = count
    }
}

public struct SidebarRow: View {
    private let item: SidebarItem

    public init(_ item: SidebarItem) {
        self.item = item
    }

    public var body: some View {
        Label(item.title, systemImage: item.systemImage)
            .badge(item.count ?? 0)
    }
}
