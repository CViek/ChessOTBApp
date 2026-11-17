import SwiftUI

struct MeetingPlaceSearchView: View {
    @StateObject private var model = MeetingPlaceSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    let onSelect: (MeetingPlace) -> Void
    var body: some View {
        List {
            Section {
                Text("Search a venue or street address. Include a city to narrow the results.")
                    .font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
            }
            if model.isLoading { ProgressView("Searching addresses…") }
            if let error = model.errorMessage { AccountFeedback(message: error, isError: true) }
            if model.hasSearched && model.results.isEmpty {
                Text("No addresses found. Try the street address or add a city.")
            }
            ForEach(model.results) { place in
                Button {
                    onSelect(place); dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(place.name).font(DesignTokens.Typography.control)
                        Text(place.address).font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 6)
                }.buttonStyle(.plain).accessibilityIdentifier("meeting.addressResult")
            }
        }
        .scrollContentBackground(.hidden).background(DesignTokens.Colors.paper)
        .navigationTitle("Meeting address").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.query, prompt: "Venue or full address")
        .task(id: model.query) { await model.search() }
        .refreshable { await model.search() }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }
}

#if DEBUG
#Preview { NavigationStack { MeetingPlaceSearchView { _ in } } }
#endif
