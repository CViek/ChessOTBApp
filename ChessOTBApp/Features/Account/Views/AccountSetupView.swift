import SwiftUI

struct AccountSetupView: View {
    @ObservedObject var model: ProfileViewModel
    @State private var saveRequest = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.regular) {
                BoardMark().padding(.bottom, DesignTokens.Spacing.regular)
                Text("Set up your profile").font(DesignTokens.Typography.setupTitle).accessibilityAddTraits(.isHeader)
                AccountField(title: "What should players call you?", text: $model.displayNameDraft, identifier: "profile.name")
                Text("Your display name appears on your public profile. Your email stays private.")
                    .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
                if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                if model.isSaving { ProgressView("Saving…") }
                PrimaryButton(title: "Save profile") { saveRequest += 1 }
                    .disabled(!model.canSave).accessibilityIdentifier("profile.save")
            }.padding(DesignTokens.Spacing.setupInset)
        }
        .background(DesignTokens.Colors.paper)
        .navigationTitle("Your profile")
        .disabled(model.isSaving)
        .task(id: saveRequest) {
            if saveRequest > 0 { _ = await model.save(displayName: model.displayNameDraft) }
        }
    }
}

#if DEBUG
#Preview("Profile setup") {
    AccountSetupView(model: ProfileViewModel(service: PreviewAccountService(profile: nil)))
}

#endif
