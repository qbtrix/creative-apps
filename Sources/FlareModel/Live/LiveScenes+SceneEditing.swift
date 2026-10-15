// LiveScenes+SceneEditing.swift: the live scene editor, part five (docs/blueprints/flare/features/live-scenes.md,
// task SN-5). Declares the `SceneEditing` conformance; the methods themselves are in LiveScenes.swift (new, add,
// remove), LiveScenes+Order.swift (rename, reorder), LiveScenes+Canvas.swift (canvas, timing) and
// LiveScenes+Guides.swift (guides). `FlareServices.live` swaps it in at IN-4.
import FlareCore

extension LiveScenes: SceneEditing {}
