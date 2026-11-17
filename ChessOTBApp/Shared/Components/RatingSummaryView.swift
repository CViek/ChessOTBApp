import SwiftUI

struct RatingSummaryView: View {
    let ratings: [RatingEntry]
    init(rating: RatingEntry?) { ratings = rating.map { [$0] } ?? [] }
    init(ratings: [RatingEntry]) { self.ratings = ratings }
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
            if ratings.isEmpty { Text("Rating not provided") }
            ForEach(ratings, id: \.kind) { Text($0.summary) }
        }
            .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
