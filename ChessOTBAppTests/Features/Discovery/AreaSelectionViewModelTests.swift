import Foundation
import Testing
@testable import ChessOTBApp

@MainActor struct AreaSelectionViewModelTests {
    private func model(_ profile: ProfileDouble = ProfileDouble(), denied: Bool = false) -> AreaSelectionViewModel {
        AreaSelectionViewModel(purpose: .initialProfile,
            areas: AreaService(lookup: AreaLookupDouble([DiscoveryFixtures.newYork, DiscoveryFixtures.boston]), location: LocationDouble(denied: denied)),
            profiles: profile, discovery: DiscoveryDouble())
    }
    @Test func ambiguousResultsRequireAnExplicitChoiceBeforeSave() async {
        let model = model(); model.query = "City"
        await model.resolve()
        #expect(model.candidates.count == 2)
        #expect(model.selected == nil)
        #expect(await model.save() == false)
        guard let candidate = model.candidates.first else { Issue.record("No candidates"); return }
        model.select(candidate)
        #expect(await model.save())
        #expect(model.savedProfile?.areaName == "New York, NY")
    }
    @Test func editingQueryInvalidatesSelectedArea() async {
        let model = model(); model.query = "City"; await model.resolve()
        guard let candidate = model.candidates.first else { Issue.record("No candidates"); return }
        model.select(candidate)
        model.query = "Boston"
        #expect(model.selected == nil)
        #expect(await model.save() == false)
    }
    @Test func failedSavePreservesDraftAndDoesNotCompleteOnboarding() async {
        let profile = ProfileDouble(); let model = model(profile)
        model.query = "City"; await model.resolve()
        guard let candidate = model.candidates.first else { Issue.record("No candidates"); return }
        model.select(candidate); profile.setFailure(.network)
        #expect(await model.save() == false)
        #expect(model.didSave == false)
        #expect(model.selected == candidate)
        #expect(model.errorMessage != nil)
    }
    @Test func denialAllowsManualRecovery() async {
        let model = model(denied: true)
        await model.resolve(currentLocation: true)
        #expect(model.errorMessage != nil)
        model.query = "City"; await model.resolve()
        #expect(model.candidates.count == 2)
    }
}

@MainActor private final class ControlledAreaService: AreaServiceProtocol {
    private var pending: CheckedContinuation<[ApproximateArea], Never>?
    var isWaiting: Bool { pending != nil }
    func finishOldRequest() { pending?.resume(returning: [DiscoveryFixtures.newYork]); pending = nil }
    @MainActor func resolve(query: String) async throws -> [ApproximateArea] {
        if query == "Offline" { throw AreaError.locationUnavailable }
        if query == "Old" { return await withCheckedContinuation { pending = $0 } }
        return [DiscoveryFixtures.boston]
    }
    @MainActor func currentArea() async throws -> [ApproximateArea] { throw AreaError.permissionDenied }
}

extension AreaSelectionViewModelTests {
    @Test func staleResolutionCannotRestoreAnOldChoice() async throws {
        let service = ControlledAreaService()
        let model = AreaSelectionViewModel(purpose: .search, areas: service, profiles: ProfileDouble(), discovery: DiscoveryDouble())
        model.query = "Old"
        let old = Task { await model.resolve() }
        for _ in 0..<100 {
            if service.isWaiting { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard service.isWaiting else { old.cancel(); Issue.record("Lookup did not start"); return }
        model.query = "Boston"
        await model.resolve(); model.select(DiscoveryFixtures.boston)
        service.finishOldRequest(); await old.value
        #expect(model.selected == DiscoveryFixtures.boston)
        #expect(model.candidates == [DiscoveryFixtures.boston])
    }
    @Test func offlineLookupCanBeRetriedWithoutSavingAnUnresolvedDraft() async {
        let model = AreaSelectionViewModel(purpose: .search, areas: ControlledAreaService(), profiles: ProfileDouble(), discovery: DiscoveryDouble())
        model.query = "Offline"; await model.resolve()
        #expect(model.errorMessage != nil)
        #expect(await model.save() == false)
        model.query = "Boston"; await model.resolve()
        #expect(model.errorMessage == nil)
        #expect(model.candidates == [DiscoveryFixtures.boston])
        model.select(DiscoveryFixtures.boston)
        #expect(await model.save())
        #expect(model.savedSettings?.area == DiscoveryFixtures.boston)
        #expect(model.savedProfile == nil)
    }
}
