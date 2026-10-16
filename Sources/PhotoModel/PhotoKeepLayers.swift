// PhotoKeepLayers.swift: the words of "Keep layers?", which File > Save asks
// when a flat file's image has layers (photo-documents, PJ-1). The
// informative text names both files, so a first-time reader knows Save as
// Photo Document writes a new `<name>.ora` beside the flat file and leaves
// that file as it is. The app builds its NSAlert sheet from these, each
// button with its identifier. Linux-safe.

/// "Keep layers?": its title, buttons and their answers.
public enum PhotoKeepLayers {
    /// What the person chose.
    public enum Answer: Sendable, Hashable {
        case saveDocument
        case flatten(ImageFormat)
        case cancel
    }

    /// One of the sheet's buttons, in the order the sheet adds them.
    public struct Choice: Sendable, Equatable {
        public let title: String
        public let identifier: String
        public let answer: Answer
    }

    public static let title = "Keep layers?"

    /// Save as Photo Document (the default, Return), Flatten into `format`, Cancel (Escape).
    public static func choices(format: ImageFormat) -> [Choice] {
        [
            Choice(title: "Save as Photo Document", identifier: "photo.file.keep-layers.document", answer: .saveDocument),
            Choice(title: "Flatten into \(format.title)", identifier: "photo.file.keep-layers.flatten",
                   answer: .flatten(format)),
            Choice(title: "Cancel", identifier: "photo.file.keep-layers.cancel", answer: .cancel),
        ]
    }

    /// The answer for the button at `index` (0 is the first); Cancel for any other.
    public static func answer(forButton index: Int, format: ImageFormat) -> Answer {
        let choices = choices(format: format)
        return choices.indices.contains(index) ? choices[index].answer : .cancel
    }
}

extension PhotoWorkspace {
    /// "beach.png can keep only one flat layer. Save as Photo Document writes
    /// beach.ora next to it with every layer, mask and adjustment, and leaves
    /// beach.png as it is." An image with no name is "Untitled" in `format`.
    public func keepLayersMessage(format: ImageFormat) -> String {
        let flat = documentName ?? fileName(for: format)
        return "\(flat) can keep only one flat layer. Save as Photo Document writes \(documentFileName) next to it "
            + "with every layer, mask and adjustment, and leaves \(flat) as it is."
    }
}
