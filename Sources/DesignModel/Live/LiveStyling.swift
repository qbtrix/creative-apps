// Live/LiveStyling.swift: the inspector's style rows on the live services.
// Until the style-rows feature takes this file over, every help and write
// forwards to NotBuilt("Style editing"), so a row through this use case is
// disabled with "Style editing isn't built yet." and never acts. Linux-safe.

public struct LiveStyling: StyleEditing {
    private let base = NotBuilt("Style editing")
    public init() {}

    public func styleHelp(_ property: DesignStyleProperty, _ ids: [String], on page: DesignPage) -> String? {
        base.styleHelp(property, ids, on: page)
    }
    public func setFrame(_ field: DesignFrameField, to value: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.setFrame(field, to: value, ids, on: page)
    }
    public func setFill(_ color: DesignColor, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.setFill(color, ids, on: page)
    }
    public func setCornerRadius(_ radius: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.setCornerRadius(radius, ids, on: page)
    }
    public func setOpacity(_ opacity: Double, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.setOpacity(opacity, ids, on: page)
    }
    public func setStroke(_ stroke: DesignStroke?, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.setStroke(stroke, ids, on: page)
    }
    public func setTextStyle(_ style: DesignTextStyle, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.setTextStyle(style, ids, on: page)
    }
}
