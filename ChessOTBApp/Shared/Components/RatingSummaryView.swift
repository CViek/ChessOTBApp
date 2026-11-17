import SwiftUI

struct RatingSummaryView: View {
    let rating: RatingEntry?
    var body: some View {
        Text(rating?.summary ?? String(localized: "Rating not provided"))
            .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
