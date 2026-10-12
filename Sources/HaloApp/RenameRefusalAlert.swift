// RenameRefusalAlert.swift: the system alert shown when HaloProject refuses a
// composition rename (a taken or empty name). It says why and offers the
// user's own name back in a field to fix, so the edit is never lost. Rename
// stays disabled while HaloProject would still refuse the name. The alert owns
// only its draft (presentation state); the refusal lives in HaloProject.
import HaloModel
import SwiftUI

struct RenameRefusalAlert: ViewModifier {
    let refusal: RefusedRename?
    var problem: @MainActor (RefusedRename, String) -> String? = { _, _ in nil }
    var onRename: @MainActor (RefusedRename, String) -> Void = { _, _ in }
    var onDismiss: @MainActor () -> Void = {}
    @State private var draft: String?

    func body(content: Content) -> some View {
        content
            .alert(
                "Can’t Rename Composition",
                isPresented: Binding(get: { refusal != nil }, set: { if !$0 { onDismiss() } }),
                presenting: refusal
            ) { refusal in
                TextField("Name", text: Binding(get: { draft ?? refusal.name }, set: { draft = $0 }))
                Button("Rename") { onRename(refusal, draft ?? refusal.name) }
                    .disabled(problem(refusal, draft ?? refusal.name) != nil)
                Button("Cancel", role: .cancel) { onDismiss() }
            } message: { refusal in
                Text(refusal.problem)
            }
            .onChange(of: refusal) { _, _ in draft = nil }
    }
}
