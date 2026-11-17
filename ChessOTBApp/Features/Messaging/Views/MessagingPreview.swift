#if DEBUG
import SwiftUI

private struct MessagingPreview: View {
    let state: PreviewMessagingService.State
    var showConversation = false
    @State private var workspace: MessagingWorkspace?
    @State private var error: String?
    @State private var peerID = UUID()
    var body: some View {
        NavigationStack {
            if let workspace {
                if showConversation {
                    ConversationView(route: ConversationRoute(peerID: peerID, displayName: "Alex Morgan"), workspace: workspace)
                } else { InboxView(model: workspace.inbox) }
            } else if let error { Text(error) }
            else { ProgressView() }
        }
        .environment(SessionViewModel(auth: PreviewAccountService()))
        .environment(AppearanceSettings())
        .task {
            do {
                workspace = MessagingWorkspace(cache: try AccountCache(accountID: UUID(), inMemory: true),
                                               service: PreviewMessagingService(state: state, peerID: peerID), ownProfileID: UUID())
            } catch { self.error = error.localizedDescription }
        }
    }
}

#Preview("Inbox") { MessagingPreview(state: .populated) }
#Preview("Empty inbox") { MessagingPreview(state: .empty) }
#Preview("Unavailable inbox") { MessagingPreview(state: .unavailable) }
#Preview("Conversation") { MessagingPreview(state: .populated, showConversation: true) }
#Preview("Empty conversation") { MessagingPreview(state: .empty, showConversation: true) }
#Preview("Unavailable conversation") { MessagingPreview(state: .unavailable, showConversation: true) }
#Preview("Message bubbles") {
    VStack { MessageBubble(bodyText: "Saturday afternoon?", mine: false); MessageBubble(bodyText: "That works for me.", mine: true) }.padding()
}
#endif
