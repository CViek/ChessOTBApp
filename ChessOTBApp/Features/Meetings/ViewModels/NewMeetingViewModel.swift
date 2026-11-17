import Combine
import Foundation

@MainActor final class NewMeetingViewModel: ObservableObject {
    @Published private(set) var proposal: ProposalViewModel?
    @Published private(set) var peerName: String?
    @Published private(set) var isOpening = false
    @Published private(set) var errorMessage: String?
    private let workspace: MessagingWorkspace
    init(workspace: MessagingWorkspace) { self.workspace = workspace }
    func select(_ friend: Friendship) async {
        guard !isOpening, workspace.cache.isActive else { return }
        isOpening = true; errorMessage = nil
        defer { isOpening = false }
        do {
            let model = try await workspace.proposalForFriend(peerID: friend.peerID)
            guard workspace.cache.isActive, !Task.isCancelled else { return }
            proposal = model; peerName = friend.displayName
        } catch is CancellationError { return }
        catch {
            guard workspace.cache.isActive else { return }
            errorMessage = String(localized: "Could not start this proposal. Check your connection and that you are still friends, then try again.")
        }
    }
}
