// Availability/HaloAvailability+Keys.swift: whether the TRANSFORM rows, the
// stopwatch, the key diamond, Parent, Blend and the viewer drag can act now
// (#38, #207). Every one needs a composition. The inspector's controls also
// need a selected layer; the viewer drag doesn't, since a drag selects the
// layer it hits. With those, a control acts unless the service it calls says
// why not: keying for the rows, stopwatch, diamond and Parent (placing too
// for Parent's choices), dragging for the viewer drag. Blend is a plain
// layer edit and needs no service. Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func keysHelp(_ command: HaloCommand) -> String? {
        guard selectedComposition != nil else { return HaloEditError.noComposition.message }
        switch command {
        case .beginViewerDrag, .moveViewerDrag, .endViewerDrag, .cancelViewerDrag:
            return services.dragging.unavailableHelp
        default:
            break
        }
        guard selectedLayer != nil else { return HaloEditError.noLayerSelected.message }
        switch command {
        case .setBlendMode:
            return nil
        case .setParent:
            return services.keying.unavailableHelp ?? services.placing.unavailableHelp
        default:
            return services.keying.unavailableHelp
        }
    }
}
