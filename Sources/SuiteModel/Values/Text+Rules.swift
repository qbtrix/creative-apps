// Text+Rules.swift: `TextRules.validated` (shell-text). ST-1 declares the
// two calls so callers and ST-2's disabled `TextRulesTests` compile; until
// ST-3 writes the rules here, each returns its value unchanged.

extension TextRules {
    /// `span`, once its size, weight, colour and tracking are inside the rules.
    public static func validated(_ span: TextSpan) throws(SuiteError) -> TextSpan { span }

    /// `placed`, once its span passes and it has one finite origin and angle per grapheme.
    public static func validated(_ placed: PlacedSpan) throws(SuiteError) -> PlacedSpan { placed }
}
