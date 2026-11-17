import SwiftUI

struct PrimaryButton: View {
    let title: LocalizedStringKey
    var kind: Kind = .primary
    let action: () -> Void

    enum Kind {
        case primary, secondary, quiet, danger
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(NotationButtonStyle(kind: kind))
    }
}

private struct NotationButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let kind: PrimaryButton.Kind

    private var foreground: Color {
        switch kind {
        case .primary: DesignTokens.Colors.paper
        case .danger: DesignTokens.Colors.danger
        case .secondary, .quiet: DesignTokens.Colors.forest
        }
    }

    private var background: Color {
        switch kind {
        case .primary: DesignTokens.Colors.forest
        case .secondary: DesignTokens.Colors.surface
        case .quiet, .danger: .clear
        }
    }

    private var border: Color {
        switch kind {
        case .secondary: DesignTokens.Colors.line
        case .danger: DesignTokens.Colors.danger.opacity(0.65)
        case .primary, .quiet: .clear
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.control)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, DesignTokens.Spacing.medium)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Size.controlHeight)
            .foregroundStyle(foreground)
            .background(background, in: .rect(cornerRadius: DesignTokens.Radius.action))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.action)
                    .strokeBorder(border, lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: DesignTokens.Radius.action))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
    }
}

#Preview("Actions · Light") {
    VStack(spacing: DesignTokens.Spacing.small) {
        PrimaryButton(title: "Choose my search area") {}
        PrimaryButton(title: "Enter area manually", kind: .secondary) {}
        PrimaryButton(title: "Not now", kind: .quiet) {}
        PrimaryButton(title: "Cancel Meeting", kind: .danger) {}
        PrimaryButton(title: "Choose my search area") {}.disabled(true)
    }
    .padding().background(DesignTokens.Colors.paper)
}

#Preview("Actions · Dark, large text") {
    VStack {
        PrimaryButton(title: "Choose my search area") {}
        PrimaryButton(title: "Enter area manually", kind: .secondary) {}
        PrimaryButton(title: "Cancel Meeting", kind: .danger) {}
    }
    .padding().background(DesignTokens.Colors.paper)
    .preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
