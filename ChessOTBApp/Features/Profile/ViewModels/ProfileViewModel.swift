import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var displayNameDraft = ""
    @Published var ratingDrafts: [RatingDraft] = []
    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsSignIn = false
    private let service: any ProfileServiceProtocol

    init(service: any ProfileServiceProtocol) { self.service = service }

    var canSave: Bool { !displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving }

    func acceptAreaProfile(_ profile: PlayerProfile) { self.profile = profile }

    func prepareDraft() {
        displayNameDraft = profile?.displayName ?? ""
        ratingDrafts = profile?.ratings.map { RatingDraft(kind: $0.kind, value: String($0.value)) } ?? []
        errorMessage = nil
    }

    var canAddRating: Bool { ratingDrafts.count < RatingKind.allCases.count }

    func availableKinds(for draft: RatingDraft) -> [RatingKind] {
        RatingKind.allCases.filter { kind in
            !ratingDrafts.contains { $0.id != draft.id && $0.kind == kind }
        }
    }

    func addRating() {
        guard let kind = RatingKind.allCases.first(where: { kind in !ratingDrafts.contains { $0.kind == kind } }) else { return }
        ratingDrafts.append(RatingDraft(kind: kind, value: ""))
    }

    func removeRating(id: UUID) { ratingDrafts.removeAll { $0.id == id } }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.loadOwnProfile()
            try Task.checkCancellation()
            profile = result
            displayNameDraft = result?.displayName ?? ""
            hasLoaded = true
        } catch is CancellationError { return }
        catch { record(error) }
    }

    func save(displayName: String) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let name = try PlayerProfile.validatedName(displayName)
            let result = try await service.saveDisplayName(name)
            try Task.checkCancellation()
            profile = result
            hasLoaded = true
            return true
        } catch is CancellationError { return false }
        catch { record(error); return false }
    }

    func saveEdits() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true; errorMessage = nil
        defer { isSaving = false }
        do {
            let ratings = try ratingDrafts.compactMap { try RatingEntry.parse(kind: $0.kind, text: $0.value) }
            guard Set(ratings.map(\.kind)).count == ratings.count else { throw RatingError.duplicateKind }
            let result = try await service.saveProfile(displayName: displayNameDraft, ratings: ratings)
            try Task.checkCancellation()
            profile = result; hasLoaded = true
            return true
        } catch is CancellationError { return false }
        catch { record(error); return false }
    }
    private func record(_ error: Error) {
        errorMessage = error.localizedDescription
        needsSignIn = [.unauthorized, .sessionExpired].contains(error as? APIError)
    }
}
