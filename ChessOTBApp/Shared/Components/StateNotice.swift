import SwiftUI

/// Figma's informational .notice. Feature-specific error and loading layouts
/// remain owned by their implementation phases and approved designs.
struct StateNotice: View {
    let message: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image("IconInfo")
                .resizable()
                .frame(width: 19, height: 19)
                .accessibilityHidden(true)
            Text(message)
                .font(DesignTokens.Typography.notice)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.medium)
        .foregroundStyle(DesignTokens.Colors.forest)
        .background(DesignTokens.Colors.sage, in: .rect(cornerRadius: DesignTokens.Radius.field))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Notice · Light") {
    StateNotice(message: "Location access is off. Manual search works just as well.")
        .padding().background(DesignTokens.Colors.paper)
}

#Preview("Notice · Dark, large text") {
    StateNotice(message: "Location access is off. Manual search works just as well.")
        .padding().background(DesignTokens.Colors.paper)
        .preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
