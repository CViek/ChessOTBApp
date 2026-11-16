import SwiftUI

struct SearchAreaView: View {
    @StateObject private var model: AreaSelectionViewModel
    @StateObject private var radiusInput: RadiusInputViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionViewModel.self) private var session
    @State private var manual: Bool
    @State private var resolveRequest = 0
    @State private var useLocation = false
    @State private var saveRequest = 0
    @FocusState private var queryFocused: Bool
    let onSaved: (PlayerProfile?, DiscoverySettings?) -> Void

    init(purpose: AreaSelectionViewModel.Purpose, areas: any AreaServiceProtocol,
         profiles: any ProfileServiceProtocol, discovery: any DiscoveryServiceProtocol,
         settings: DiscoverySettings? = nil, onSaved: @escaping (PlayerProfile?, DiscoverySettings?) -> Void) {
        _model = StateObject(wrappedValue: AreaSelectionViewModel(purpose: purpose, areas: areas, profiles: profiles, discovery: discovery, settings: settings))
        _radiusInput = StateObject(wrappedValue: RadiusInputViewModel(radius: settings?.radius ?? .five))
        _manual = State(initialValue: purpose != .initialProfile)
        self.onSaved = onSaved
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                AreaOrbit().frame(maxWidth: .infinity).padding(.top, 12)
                Text(model.purpose == .profile ? "Your profile area" : "Where should we look?")
                    .font(DesignTokens.Typography.setupTitle).accessibilityAddTraits(.isHeader)
                Text(model.purpose == .search
                     ? "Choose a city or neighborhood to search. This keeps your public profile area unchanged."
                     : "Choose a city or neighborhood to appear in nearby searches. Players see this area and an approximate distance, never your device coordinates.")
                    .font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                PrimaryButton(title: "Use current location", kind: .secondary) {
                    queryFocused = false; manual = true; useLocation = true; resolveRequest += 1
                }.accessibilityIdentifier("area.currentLocation")
                if manual { manualEntry }
                else {
                    PrimaryButton(title: "Enter area manually", kind: .secondary) { manual = true; queryFocused = true }
                        .accessibilityIdentifier("area.manual")
                    PrimaryButton(title: "Not now", kind: .quiet) { manual = true; queryFocused = true }
                }
                if model.isResolving { ProgressView("Finding areas…").accessibilityIdentifier("area.loading") }
                if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                if !model.candidates.isEmpty { candidates }
                if manual {
                    if model.purpose != .profile { RadiusPicker(input: radiusInput) }
                    if model.isSaving { ProgressView("Saving…") }
                    PrimaryButton(title: model.purpose == .initialProfile ? "Find nearby players" : "Save area") {
                        queryFocused = false
                        if let radius = radiusInput.radius { model.radius = radius; saveRequest += 1 }
                    }.disabled(model.selected == nil || model.isResolving || radiusInput.radius == nil).accessibilityIdentifier("area.save")
                }
                Text("Current-location lookup uses Apple Maps to resolve a named area. Only that area's approximate center is saved.")
                    .font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
            }.padding(DesignTokens.Spacing.setupInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignTokens.Colors.paper)
        .navigationTitle(model.purpose == .profile ? "Profile area" : "Search area")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.purpose != .initialProfile {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(model.isSaving) }
            }
        }
        .interactiveDismissDisabled(model.isSaving)
        .disabled(model.isSaving)
        .task { await model.loadInitial() }
        .task(id: resolveRequest) { if resolveRequest > 0 { await model.resolve(currentLocation: useLocation) } }
        .task(id: saveRequest) {
            if saveRequest > 0, await model.save() {
                onSaved(model.savedProfile, model.savedSettings)
                if model.purpose != .initialProfile { dismiss() }
            }
        }
        .task(id: model.needsSignIn) { if model.needsSignIn { await session.signOut() } }
    }
    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("City or neighborhood").font(DesignTokens.Typography.eyebrow)
            TextField("e.g. Brooklyn, NY", text: $model.query)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
                .font(DesignTokens.Typography.field).padding(12)
                .background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignTokens.Colors.line))
                .focused($queryFocused).submitLabel(.search)
                .onSubmit { resolveManually() }
                .accessibilityLabel("City or neighborhood").accessibilityIdentifier("area.query")
            PrimaryButton(title: "Search areas", kind: .secondary) { resolveManually() }
                .disabled(model.query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                .accessibilityIdentifier("area.search")
        }
    }
    private var candidates: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Choose an area").font(DesignTokens.Typography.eyebrow)
            ForEach(model.candidates) { area in
                Button { model.select(area) } label: {
                    HStack(spacing: 12) {
                        Image("IconPin").accessibilityHidden(true)
                        Text(area.name).frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: model.selected == area ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
                    }.padding(.vertical, 12).contentShape(Rectangle())
                }.accessibilityIdentifier("area.candidate.\(area.name)")
                    .accessibilityAddTraits(model.selected == area ? .isSelected : [])
                Divider()
            }
        }
    }
    private func resolveManually() { queryFocused = false; useLocation = false; resolveRequest += 1 }
}

struct RadiusPicker: View {
    @ObservedObject var input: RadiusInputViewModel
    @FocusState private var editingMiles: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search distance").font(DesignTokens.Typography.eyebrow)
            Slider(value: Binding(get: { input.sliderValue }, set: { input.sliderValue = $0 }),
                   in: Double(SearchRadius.allowedRange.lowerBound)...Double(SearchRadius.allowedRange.upperBound), step: 1)
                .accessibilityLabel("Search distance").accessibilityValue(input.sliderLabel).accessibilityIdentifier("discovery.radius")
            HStack(spacing: 12) {
                TextField("Miles", text: $input.text)
                    .keyboardType(.numberPad).autocorrectionDisabled().focused($editingMiles)
                    .font(DesignTokens.Typography.field).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.Colors.surface, in: .rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DesignTokens.Colors.line))
                    .accessibilityLabel("Distance in miles").accessibilityIdentifier("discovery.radiusMiles")
                Text("miles").font(DesignTokens.Typography.notice)
            }
            Text("1–100 miles").font(DesignTokens.Typography.caption).foregroundStyle(DesignTokens.Colors.muted)
            if let error = input.errorMessage { AccountFeedback(message: error, isError: true) }
        }
        .toolbar {
            if editingMiles {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editingMiles = false }.accessibilityIdentifier("discovery.radiusDone")
                }
            }
        }
    }
}

struct AreaOrbit: View {
    var body: some View {
        ZStack {
            Circle().stroke(DesignTokens.Colors.line, lineWidth: 1).frame(width: 150, height: 150)
            Circle().stroke(DesignTokens.Colors.line, lineWidth: 1).frame(width: 108, height: 108)
            Image("IconPin").resizable().scaledToFit().frame(width: 28, height: 28)
                .padding(20).background(DesignTokens.Colors.sage, in: .circle)
            Circle().fill(DesignTokens.Colors.oxblood).frame(width: 10, height: 10).offset(x: 60, y: -42)
        }.frame(width: 160, height: 160).accessibilityHidden(true)
    }
}

#if DEBUG
private struct AreaPreview: View {
    let purpose: AreaSelectionViewModel.Purpose
    var state: PreviewPlayerService.State = .populated
    var body: some View {
        NavigationStack {
            SearchAreaView(purpose: purpose, areas: PreviewAccountService(), profiles: PreviewPlayerService(state: state),
                           discovery: PreviewDiscoveryService(state: .empty), settings: purpose == .search ? PreviewDiscoveryService.settings : nil) { _, _ in }
        }.environment(SessionViewModel(auth: PreviewAccountService()))
    }
}
#Preview("Area · onboarding") { AreaPreview(purpose: .initialProfile) }
#Preview("Area · selected") { AreaPreview(purpose: .search).preferredColorScheme(.dark) }
#Preview("Area · loading") { AreaPreview(purpose: .profile, state: .loading) }
#Preview("Area · error") { AreaPreview(purpose: .profile, state: .failed) }
#endif
