// Text+Rules.swift: `TextRules.validated` (shell-text ST-3). A span is drawn
// only when its size is inside `sizes`, its weight is 100...900 in hundreds,
// its colour is 4 bytes, its tracking is finite and it has at most
// `maxGraphemes` graphemes; a placed span also needs one finite origin and
// one finite angle per grapheme. The family is never refused: an empty name
// is the system UI font, and an unknown one falls back to it when measured,
// with `SpanMetrics.resolvedFamily` naming what drew it, so a document from
// another Mac still draws.

extension TextRules {
    /// `span`, once its size, weight, colour and tracking are inside the rules.
    public static func validated(_ span: TextSpan) throws(SuiteError) -> TextSpan {
        guard span.fontSize >= sizes.lowerBound, span.fontSize <= sizes.upperBound else {
            throw .notAvailable("Text sizes run from 1 to 1,600 points.")
        }
        guard (100...900).contains(span.weight), span.weight % 100 == 0 else {
            throw .notAvailable("Font weights run from 100 to 900 in steps of 100.")
        }
        guard span.rgba.count == 4 else { throw .notAvailable("A text colour needs red, green, blue and alpha.") }
        guard span.tracking.isFinite else { throw .notAvailable("Text tracking must be a number.") }
        guard span.string.count <= maxGraphemes else {
            throw .notAvailable("A span can hold at most 100,000 characters.")
        }
        return span
    }

    /// `placed`, once its span passes and it has one finite origin and angle per grapheme.
    public static func validated(_ placed: PlacedSpan) throws(SuiteError) -> PlacedSpan {
        _ = try validated(placed.span)
        let graphemes = placed.span.string.count
        guard placed.origins.count == graphemes, placed.degrees.count == graphemes else {
            throw .notAvailable("Placed text needs one position and one angle per character.")
        }
        guard placed.origins.allSatisfy({ $0.x.isFinite && $0.y.isFinite }), placed.degrees.allSatisfy(\.isFinite) else {
            throw .notAvailable("Placed text positions and angles must be numbers.")
        }
        return placed
    }
}
