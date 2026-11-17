import SwiftUI

struct MessagingDestinations: ViewModifier {
    let workspace: MessagingWorkspace
    let profiles: any ProfileServiceProtocol
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: ConversationRoute.self) { route in
                ConversationView(route: route, workspace: workspace)
            }
            .navigationDestination(for: MeetingRoute.self) { route in
                if let model = workspace.detail(id: route.id) { MeetingDetailView(model: model, workspace: workspace) }
            }
            .navigationDestination(for: PublicPlayerRoute.self) { route in
                PlayerProfileView(id: route.id, service: profiles, workspace: workspace)
            }
    }
}
