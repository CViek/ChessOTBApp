import SwiftUI

struct EditProfileView: View {
    @ObservedObject var model: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var saveRequest = 0
    @State private var prepared = false
    @FocusState private var enteringRating: Bool
    var editArea: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.regular) {
                AccountField(title: "Display name", text: $model.displayNameDraft, identifier: "profile.name")
                Button(action: editArea) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Profile area").font(DesignTokens.Typography.eyebrow)
                            Text(model.profile?.areaName ?? String(localized: "Choose an area")).font(DesignTokens.Typography.notice)
                        }
                        Spacer(); Image("IconChevron").accessibilityHidden(true)
                    }.frame(minHeight: 50)
                }.accessibilityIdentifier("profile.editArea")
                Text("Changing your profile area keeps your search area unchanged.")
                    .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
                Divider()
                Text("Optional rating").font(DesignTokens.Typography.sectionTitle)
                Picker("Rating source and format", selection: $model.ratingKind) {
                    ForEach(RatingKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }.accessibilityIdentifier("profile.ratingKind")
                TextField("Leave blank for no rating", text: $model.ratingValueDraft)
                    .keyboardType(.numberPad).focused($enteringRating)
                    .padding(12).background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 10))
                    .accessibilityLabel("Rating value").accessibilityIdentifier("profile.ratingValue")
                Button("Remove rating") { model.ratingValueDraft = "" }.frame(minHeight: 44)
                    .accessibilityIdentifier("profile.removeRating")
                Text("Self-reported. Ratings are not verified or synchronized. Enter 1–4,000, or leave blank.")
                    .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
                if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                if model.isSaving { ProgressView("Saving…") }
                PrimaryButton(title: "Save") { enteringRating = false; saveRequest += 1 }
                    .disabled(!model.canSave).accessibilityIdentifier("profile.save")
            }.padding(DesignTokens.Spacing.pageInset)
        }
        .background(DesignTokens.Colors.paper)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { enteringRating = false } } }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(model.isSaving)
        .interactiveDismissDisabled(model.isSaving)
        .disabled(model.isSaving)
        .task { if !prepared { model.prepareDraft(); prepared = true } }
        .task(id: saveRequest) {
            if saveRequest > 0, await model.saveEdits() { dismiss() }
        }
    }
}

#if DEBUG
#Preview("Edit display name") {
    NavigationStack { EditProfileView(model: ProfileViewModel(service: PreviewAccountService())) }
}

#endif
