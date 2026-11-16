import SwiftUI

struct SearchFiltersView: View {
    @ObservedObject var model: DiscoveryViewModel
    @StateObject private var radiusInput: RadiusInputViewModel
    @State private var applyRequest = 0
    @Environment(\.dismiss) private var dismiss
    init(model: DiscoveryViewModel) {
        self.model = model
        _radiusInput = StateObject(wrappedValue: RadiusInputViewModel(radius: model.settings?.radius ?? .five))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    RadiusPicker(input: radiusInput)
                    Text("Distances are approximate and measured between named area centers.")
                        .font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                    if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
                    PrimaryButton(title: "Apply distance") { applyRequest += 1 }.disabled(radiusInput.radius == nil).accessibilityIdentifier("discovery.applyRadius")
                    PrimaryButton(title: "Reset to 5 miles", kind: .quiet) { radiusInput.reset() }
                    if model.isSaving { ProgressView("Saving…") }
                }.padding(22)
            }.background(DesignTokens.Colors.paper)
                .navigationTitle("Search filters").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .disabled(model.isSaving).interactiveDismissDisabled(model.isSaving)
                .task(id: applyRequest) { if applyRequest > 0, let radius = radiusInput.radius, await model.setRadius(radius) { dismiss() } }
        }
    }
}

#if DEBUG
#Preview("Distance filters") {
    @Previewable @StateObject var model = DiscoveryViewModel(service: PreviewDiscoveryService(state: .empty))
    SearchFiltersView(model: model).task { await model.refresh() }
}
#Preview("Distance filters · error") {
    @Previewable @StateObject var model = DiscoveryViewModel(service: PreviewDiscoveryService(state: .failed))
    SearchFiltersView(model: model).task { await model.refresh() }
}
#endif
