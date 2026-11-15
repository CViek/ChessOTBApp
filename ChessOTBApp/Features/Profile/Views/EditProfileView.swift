import SwiftUI

struct EditProfileView: View {
    @ObservedObject var model: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var saveRequest = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.regular) {
                AccountField(title: "Display name", text: $model.displayNameDraft, identifier: "profile.name")
                if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                if model.isSaving { ProgressView("Saving…") }
                PrimaryButton(title: "Save") { saveRequest += 1 }
                    .disabled(!model.canSave).accessibilityIdentifier("profile.save")
            }.padding(DesignTokens.Spacing.pageInset)
        }
        .background(DesignTokens.Colors.paper)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(model.isSaving)
        .interactiveDismissDisabled(model.isSaving)
        .disabled(model.isSaving)
        .task { model.prepareDraft() }
        .task(id: saveRequest) {
            if saveRequest > 0, await model.save(displayName: model.displayNameDraft) { dismiss() }
        }
    }
}

#if DEBUG
#Preview("Edit display name") {
    NavigationStack { EditProfileView(model: ProfileViewModel(service: PreviewAccountService())) }
}

#endif
