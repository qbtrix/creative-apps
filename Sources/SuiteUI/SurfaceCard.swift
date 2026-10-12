// SurfaceCard.swift: a flat card for the content layer: a title and a detail
// line on a quiet fill with a hairline border. The suite keeps content flat and
// only the outer edge glass, so cards never use glass.
import SwiftUI

public struct SurfaceCard: View {
    private let title: String
    private let detail: String

    public init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text(title).font(SuiteFont.headline)
            Text(detail).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .overlay(RoundedRectangle(cornerRadius: SuiteRadius.medium).strokeBorder(SuiteColor.separator))
    }
}
