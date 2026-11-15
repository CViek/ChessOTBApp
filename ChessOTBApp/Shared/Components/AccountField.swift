import SwiftUI

struct AccountField: View {
    enum Kind { case email, password, newPassword, code, name }
    let title: LocalizedStringKey
    @Binding var text: String
    var kind: Kind = .name
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(title).font(DesignTokens.Typography.eyebrow)
            input
                .font(DesignTokens.Typography.field)
                .padding(DesignTokens.Spacing.medium)
                .frame(minHeight: DesignTokens.Size.controlHeight)
                .background(DesignTokens.Colors.surface, in: .rect(cornerRadius: DesignTokens.Radius.field))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.field).strokeBorder(DesignTokens.Colors.line))
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
    }

    @ViewBuilder
    private var input: some View {
        switch kind {
        case .password, .newPassword:
            SecureField(title, text: $text)
                .textContentType(kind == .password ? .password : .newPassword)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        case .email:
            TextField(title, text: $text).keyboardType(.emailAddress)
                .textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
        case .code:
            TextField(title, text: $text).keyboardType(.numberPad)
                .textContentType(.oneTimeCode).textInputAutocapitalization(.never).autocorrectionDisabled()
        case .name:
            TextField(title, text: $text).textContentType(.nickname)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
        }
    }
}

#Preview("Account fields") {
    @Previewable @State var value = ""
    VStack {
        AccountField(title: "Email", text: $value, kind: .email, identifier: "email")
        AccountField(title: "Password", text: $value, kind: .password, identifier: "password")
    }.padding().background(DesignTokens.Colors.paper)
}
