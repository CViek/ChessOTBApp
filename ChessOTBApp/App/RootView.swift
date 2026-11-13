import SwiftUI

/// Phase 1 exposes only the verified brand introduction.
/// Account setup and feature destinations are added in their owning phases.
struct RootView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    BoardMark()
                        .padding(.top, DesignTokens.Spacing.large + DesignTokens.Spacing.small)
                        .padding(.bottom, DesignTokens.Spacing.medium)
                    Text("ChessOTB")
                        .font(DesignTokens.Typography.eyebrow)
                        .foregroundStyle(DesignTokens.Colors.oxblood)
                    Text("Find the player across the board.")
                        .font(DesignTokens.Typography.setupTitle)
                        .tracking(-1.3)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("foundation.title")
                    Text("Meet nearby chess players, talk first, then agree on a time and place together.")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.muted)
                        .padding(.top, DesignTokens.Spacing.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Spacing.setupInset)
            }
            .background(DesignTokens.Colors.paper)
            .foregroundStyle(DesignTokens.Colors.ink)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview("Introduction · Light") {
    RootView().preferredColorScheme(.light)
}

#Preview("Introduction · Dark, large text") {
    RootView().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
