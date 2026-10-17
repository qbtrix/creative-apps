// FlareTimelineRead.swift: what the timeline shows (draw-key-save DK-5). Its rows are `services.keyframes`' rows for
// the edited owner: the symbol being edited in place, else the selected scene. Read-only.
import FlareCore

extension FlareWorkspace {
    /// The text the timeline shows when the edited owner has no layers.
    public static let timelineEmptyMessage = "No layers yet. Draw on the stage to add one."

    /// One row per layer of the edited owner, in the owner's order; empty with no document.
    public var timelineRows: [TimelineRow] {
        guard let document, let owner = propertyOwner else { return [] }
        return services.keyframes.rows(document, owner: owner)
    }

    /// `timelineEmptyMessage` when there are no rows to show, else nil.
    public var timelineEmptyText: String? {
        timelineRows.isEmpty ? Self.timelineEmptyMessage : nil
    }

    /// The selected layer's row id; nil when no layer is selected or its row isn't shown.
    public var selectedTimelineRowID: String? {
        guard let id = selectedLayerID else { return nil }
        return timelineRows.contains { $0.layerID == id } ? id : nil
    }
}
