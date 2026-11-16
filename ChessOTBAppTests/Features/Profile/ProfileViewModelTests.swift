import Testing
@testable import ChessOTBApp

@MainActor
struct ProfileViewModelTests {
    @Test func saveFailurePreservesLastCommittedProfile() async {
        let service = ProfileDouble()
        let model = ProfileViewModel(service: service)
        await model.load()
        service.setFailure(.network)
        #expect(await model.save(displayName: "Changed") == false)
        #expect(model.profile?.displayName == "Original")
        #expect(model.errorMessage != nil)
    }
    @Test func invalidNameNeverReplacesCommittedValue() async {
        let model = ProfileViewModel(service: ProfileDouble())
        await model.load()
        #expect(await model.save(displayName: " \n ") == false)
        #expect(model.profile?.displayName == "Original")
    }
    @Test func successfulSaveUsesTrimmedName() async {
        let model = ProfileViewModel(service: ProfileDouble())
        await model.load()
        #expect(await model.save(displayName: "  New name  "))
        #expect(model.profile?.displayName == "New name")
        #expect(model.errorMessage == nil)
    }
}
