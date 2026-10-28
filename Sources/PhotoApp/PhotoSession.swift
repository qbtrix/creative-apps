// PhotoSession.swift: a Photo window's state, owned by its root (PhotoWindow)
// and shared with its views through the environment. It holds the one
// PhotoWorkspace outside Observation and republishes it as facets
// (PhotoFacets.swift), one SuiteUI Facet box each. Every write through
// `workspace` re-derives the facets when the access ends and stores only the
// ones that changed, so a body that read some facets re-runs only when one of
// them moves.
//
// A view says which facets it shows with `workspace(reading:)`, which reads
// those boxes (so its body depends on them) and hands back the workspace now.
// The window's body reads every facet but `toolOptions`; the inspector
// (PhotoPanel) and the canvas overlay read `toolOptions` themselves, so a
// brush-size step re-runs them and not the window, its editor or its canvas.
// Invariant: anything a view shows comes from a facet that it, or a view
// that re-creates it, reads.
import Observation
import PhotoModel
import SuiteUI

@MainActor @Observable final class PhotoSession {
    @ObservationIgnored private var stored: PhotoWorkspace
    let document: Facet<PhotoFacets.Document>
    let tool: Facet<PhotoFacets.Tool>
    let toolOptions: Facet<PhotoFacets.ToolOptions>
    let adjust: Facet<PhotoFacets.Adjust>
    let history: Facet<PhotoFacets.History>
    let status: Facet<PhotoFacets.Status>
    let canvas: Facet<PhotoFacets.Canvas>
    let file: Facet<PhotoFacets.File>

    init(_ workspace: PhotoWorkspace) {
        stored = workspace
        let facets = workspace.facets
        document = Facet(facets.document)
        tool = Facet(facets.tool)
        toolOptions = Facet(facets.toolOptions)
        adjust = Facet(facets.adjust)
        history = Facet(facets.history)
        status = Facet(facets.status)
        canvas = Facet(facets.canvas)
        file = Facet(facets.file)
    }

    /// The workspace now. Reading it tracks nothing; a write re-derives the facets once the access ends,
    /// in place (no copy of the layers' pixels).
    var workspace: PhotoWorkspace {
        get { stored }
        set {
            stored = newValue
            refresh()
        }
        _modify {
            defer { refresh() }
            yield &stored
        }
    }

    /// The workspace now, after reading `facets` so the calling body re-runs when one of them changes.
    func workspace(reading facets: PhotoFacet...) -> PhotoWorkspace {
        for facet in facets {
            switch facet {
            case .document: _ = document.value
            case .tool: _ = tool.value
            case .toolOptions: _ = toolOptions.value
            case .adjust: _ = adjust.value
            case .history: _ = history.value
            case .status: _ = status.value
            case .canvas: _ = canvas.value
            case .file: _ = file.value
            }
        }
        return stored
    }

    /// Re-derives every facet from the workspace and stores the ones that changed.
    private func refresh() {
        let facets = stored.facets
        document.set(facets.document)
        tool.set(facets.tool)
        toolOptions.set(facets.toolOptions)
        adjust.set(facets.adjust)
        history.set(facets.history)
        status.set(facets.status)
        canvas.set(facets.canvas)
        file.set(facets.file)
    }
}
