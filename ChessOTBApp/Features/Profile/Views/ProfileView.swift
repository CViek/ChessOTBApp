import SwiftUI

struct ProfileView: View {
    @ObservedObject var model: ProfileViewModel
    @Environment(AppearanceSettings.self) private var appearance
    @Environment(\.colorScheme) private var colorScheme
    let profile: PlayerProfile
    var editArea: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.pageInset) {
                identity
                StateNotice(message: "Your chosen profile area makes you discoverable. It doesn’t mean you’re available to play right now.")
                RatingSummaryView(ratings: profile.ratings)
                settings
                Text("Your display name appears on your public profile. Your email stays private.")
                    .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
            }.padding(DesignTokens.Spacing.pageInset)
        }
        .background(DesignTokens.Colors.paper)
        .navigationTitle("Profile")
        .navigationDestination(for: AppRoute.self) { route in
            switch route { case .editProfile: EditProfileView(model: model, editArea: editArea) }
        }
    }

    private var identity: some View {
        HStack(spacing: DesignTokens.Spacing.regular) {
            InitialsAvatar(initials: profile.initials, size: .large)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
                Text(profile.displayName).font(DesignTokens.Typography.statusTitle)
                    .accessibilityIdentifier("profile.displayName")
                Text(profile.areaName ?? String(localized: "Profile area not set")).font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, DesignTokens.Spacing.regular)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var settings: some View {
        VStack(spacing: DesignTokens.Spacing.regular) {
            NavigationLink(value: AppRoute.editProfile) {
                HStack {
                    Text("Edit profile")
                    Spacer()
                    Image("IconChevron").accessibilityHidden(true)
                }
            }
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Size.minimumTapTarget, alignment: .leading)
                .accessibilityIdentifier("profile.edit")
            Divider()
            Toggle(isOn: Binding(
                get: { appearance.darkOverride ?? (colorScheme == .dark) },
                set: { appearance.setDarkAppearance($0) }
            )) {
                HStack {
                    Image("IconMoon").accessibilityHidden(true)
                    Text("Dark appearance")
                }
            }.accessibilityIdentifier("profile.darkAppearance")
            Divider()
        }
    }
}

#if DEBUG
#Preview("Saved profile") {
    NavigationStack {
        ProfileView(model: ProfileViewModel(service: PreviewAccountService()), profile: PreviewAccountService.exampleProfile)
    }.environment(AppearanceSettings())
}

#endif
