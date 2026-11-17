import SwiftUI

struct NearbyGroupsView: View {
    @ObservedObject var model: GroupsViewModel
    let canWiden: Bool
    let widen: () -> Void
    let changeArea: () -> Void
    let retry: () -> Void
    @State private var more = 0
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            Text("Local listings with a designated contact").font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
            if let error = model.errorMessage {
                AccountFeedback(message: error, isError: true)
                PrimaryButton(title: "Retry", kind: .secondary, action: retry)
            }
            if model.isLoading { ProgressView("Finding nearby groups…").frame(maxWidth: .infinity).padding() }
            else if model.groups.isEmpty, model.errorMessage == nil {
                Text("No groups in this area").font(DesignTokens.Typography.statusTitle).accessibilityIdentifier("groups.empty")
                Text("Try increasing your distance or changing the search area.").font(DesignTokens.Typography.notice)
                if canWiden { PrimaryButton(title: "Widen search distance", action: widen) }
                PrimaryButton(title: "Change search area", kind: .secondary, action: changeArea)
            } else {
                ForEach(model.groups) { group in
                    NavigationLink(value: GroupRoute(id: group.id)) {
                        HStack(alignment: .top, spacing: 14) {
                            GroupGlyph()
                            VStack(alignment: .leading, spacing: 5) {
                                Text(group.name).font(DesignTokens.Typography.control)
                                Text(group.areaName).font(DesignTokens.Typography.caption)
                                if let distance = group.distanceDescription { Text(distance).font(DesignTokens.Typography.caption) }
                                Text(group.description).font(DesignTokens.Typography.notice).foregroundStyle(DesignTokens.Colors.muted)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Image("IconChevron").accessibilityHidden(true)
                        }.padding(.vertical, 12).contentShape(Rectangle())
                    }.accessibilityIdentifier("groups.listing.\(group.id.uuidString.lowercased())")
                    Divider()
                }
                if model.isLoadingMore { ProgressView("Loading more groups…") }
                else if model.nextCursor != nil { PrimaryButton(title: "Load more groups", kind: .secondary) { more += 1 } }
            }
        }.task(id: more) { if more > 0 { await model.loadMore() } }
    }
}

struct GroupGlyph: View {
    var large = false
    var body: some View {
        Image("IconPeople").scaleEffect(large ? 1.45 : 1)
            .frame(width: large ? 76 : 54, height: large ? 76 : 54)
            .foregroundStyle(DesignTokens.Colors.forest)
            .background(DesignTokens.Colors.sage, in: .rect(cornerRadius: 12)).accessibilityHidden(true)
    }
}
