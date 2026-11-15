import SwiftUI

struct AccountFeedback: View {
    let message: String
    var isError = false

    var body: some View {
        Text(message)
            .font(DesignTokens.Typography.notice)
            .foregroundStyle(isError ? DesignTokens.Colors.danger : DesignTokens.Colors.forest)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.medium)
            .background(DesignTokens.Colors.surface, in: .rect(cornerRadius: DesignTokens.Radius.field))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.field)
                .strokeBorder(isError ? DesignTokens.Colors.danger.opacity(0.35) : DesignTokens.Colors.line))
            .accessibilityLabel(isError ? String(localized: "Error: \(message)") : message)
            .accessibilityIdentifier(isError ? "account.error" : "account.notice")
    }
}

#Preview("Account error") {
    AccountFeedback(message: APIError.network.localizedDescription, isError: true)
        .padding().background(DesignTokens.Colors.paper)
}
