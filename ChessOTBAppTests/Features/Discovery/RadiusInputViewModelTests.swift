import Testing
@testable import ChessOTBApp

@MainActor struct RadiusInputViewModelTests {
    @Test func acceptsCustomWholeMilesAndKeepsInvalidDraftsUncommitted() {
        let input = RadiusInputViewModel(radius: .five)
        input.text = "37"
        #expect(input.radius?.rawValue == 37)
        #expect(input.errorMessage == nil)
        input.text = "101"
        #expect(input.radius == nil)
        #expect(input.errorMessage != nil)
        input.text = "7.5"
        #expect(input.radius == nil)
    }
    @Test func sliderAndResetRecoverFromInvalidTypedValues() {
        let input = RadiusInputViewModel(radius: .five)
        input.text = "invalid"
        input.sliderValue = 73
        #expect(input.text == "73")
        #expect(input.radius?.rawValue == 73)
        input.text = "0"
        input.reset()
        #expect(input.text == "5")
        #expect(input.radius == .five)
        #expect(input.errorMessage == nil)
    }
}
