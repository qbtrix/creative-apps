// PhotoUnsavedPrompt.swift: the words of the unsaved-changes alert before a
// dirty window closes or the app quits (photo-documents D-10, PJ-2, PJ-3);
// the app builds its NSAlert from these. A clean or empty image has no
// prompt (`unsavedPromptMessage` is nil). Linux-safe.

/// The unsaved-changes alert: its message, informative text and buttons.
public enum PhotoUnsavedPrompt {
    /// What the person chose.
    public enum Answer: Sendable, Equatable { case save, dontSave, cancel }

    /// One of the alert's buttons, in the order the alert adds them.
    public struct Choice: Sendable, Equatable {
        public let title: String
        public let identifier: String
        public let answer: Answer
    }

    /// Save (the default, Return), Don't Save, Cancel (Escape).
    public static let choices: [Choice] = [
        Choice(title: "Save", identifier: "photo.unsaved.save", answer: .save),
        Choice(title: "Don't Save", identifier: "photo.unsaved.dontSave", answer: .dontSave),
        Choice(title: "Cancel", identifier: "photo.unsaved.cancel", answer: .cancel),
    ]

    public static let informativeText = "Your changes will be lost if you don't save them."

    /// "Do you want to save the changes made to the document “beach.png”?"
    public static func message(for name: String) -> String {
        "Do you want to save the changes made to the document \u{201C}\(name)\u{201D}?"
    }

    /// The answer for the button at `index` (0 is the first); Cancel for any other.
    public static func answer(forButton index: Int) -> Answer {
        choices.indices.contains(index) ? choices[index].answer : .cancel
    }
}

extension PhotoWorkspace {
    /// The unsaved-changes alert's message for this image, named "Untitled"
    /// when it has no name; nil when it is clean or empty, so it closes at once.
    public var unsavedPromptMessage: String? {
        isDirty ? PhotoUnsavedPrompt.message(for: documentName ?? "Untitled") : nil
    }
}
