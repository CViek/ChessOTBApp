import SwiftUI

struct SearchFiltersView: View {
    @ObservedObject var model: DiscoveryViewModel
    let profiles: any ProfileServiceProtocol
    let areas: any AreaServiceProtocol
    let onAreaSaved: (DiscoverySettings) -> Void
    @StateObject private var radiusInput: RadiusInputViewModel
    @State private var applyRequest = 0
    @State private var ratingKind: RatingKind?
    @State private var minimum: String
    @State private var maximum: String
    private enum Bound: Hashable { case minimum, maximum }
    @FocusState private var editingBound: Bound?
    @Environment(\.dismiss) private var dismiss
    init(model: DiscoveryViewModel, profiles: any ProfileServiceProtocol, areas: any AreaServiceProtocol,
         onAreaSaved: @escaping (DiscoverySettings) -> Void) {
        self.model = model
        self.profiles = profiles
        self.areas = areas
        self.onAreaSaved = onAreaSaved
        _radiusInput = StateObject(wrappedValue: RadiusInputViewModel(radius: model.settings?.radius ?? .five))
        _ratingKind = State(initialValue: model.settings?.rating?.kind)
        _minimum = State(initialValue: model.settings?.rating?.minimum.map(String.init) ?? "")
        _maximum = State(initialValue: model.settings?.rating?.maximum.map(String.init) ?? "")
    }
    private var validationMessage: String? {
        do { _ = try RatingCriteria.parse(kind: ratingKind, minimum: minimum, maximum: maximum); return nil }
        catch { return error.localizedDescription }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    NavigationLink {
                        SearchAreaView(purpose: .search, areas: areas, profiles: profiles,
                                       discovery: model.service, settings: model.settings) { _, settings in
                            if let settings {
                                onAreaSaved(settings)
                                dismiss()
                            }
                        }
                    } label: {
                        Label("Search area", systemImage: "mappin.and.ellipse")
                            .font(DesignTokens.Typography.control)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.accessibilityIdentifier("discovery.area")
                    RadiusPicker(input: radiusInput)
                    Text("Distances are approximate and measured between named area centers.")
                        .font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                    Divider()
                    Text("Rating").font(DesignTokens.Typography.sectionTitle)
                    Picker("Rating source and format", selection: $ratingKind) {
                        Text("Any rating or unrated").tag(Optional<RatingKind>.none)
                        ForEach(RatingKind.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                    }.accessibilityIdentifier("discovery.ratingKind")
                    if ratingKind != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Minimum (optional)", text: $minimum).focused($editingBound, equals: .minimum).accessibilityIdentifier("discovery.ratingMinimum")
                            TextField("Maximum (optional)", text: $maximum).focused($editingBound, equals: .maximum).accessibilityIdentifier("discovery.ratingMaximum")
                        }.keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    Text("Compare only the same source and format. Ratings are self-reported; no rating filter includes unrated players.")
                        .font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                    if let message = validationMessage { AccountFeedback(message: message, isError: true) }
                    if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                    PrimaryButton(title: "Apply filters") { editingBound = nil; applyRequest += 1 }
                        .disabled(radiusInput.radius == nil || validationMessage != nil).accessibilityIdentifier("discovery.applyRadius")
                    PrimaryButton(title: "Clear filters", kind: .quiet) { clear() }
                    PrimaryButton(title: "Reset to 5 miles", kind: .quiet) { radiusInput.reset() }
                    if model.isSaving { ProgressView("Saving…") }
                }.padding(22)
            }.background(DesignTokens.Colors.paper)
                .navigationTitle("Search filters").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) { Button("Clear") { clear() } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editingBound = nil } }
                }
                .onChange(of: ratingKind) { _, kind in if kind == nil { minimum = ""; maximum = "" } }
                .disabled(model.isSaving).interactiveDismissDisabled(model.isSaving)
                .task(id: applyRequest) {
                    guard applyRequest > 0, let radius = radiusInput.radius else { return }
                    do {
                        let rating = try RatingCriteria.parse(kind: ratingKind, minimum: minimum, maximum: maximum)
                        if await model.setFilters(radius: radius, rating: rating) { dismiss() }
                    } catch { return } // Invalid input is displayed above and cannot be applied.
                }
        }
    }
    private func clear() { ratingKind = nil; minimum = ""; maximum = ""; radiusInput.reset() }
}

#if DEBUG
#Preview("Search filters") {
    @Previewable @StateObject var model = DiscoveryViewModel(service: PreviewDiscoveryService(state: .empty))
    SearchFiltersView(model: model, profiles: PreviewPlayerService(state: .populated), areas: PreviewAccountService()) { _ in }.task { await model.refresh() }
}
#endif
