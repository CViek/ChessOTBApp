import Testing
@testable import ChessOTBApp

struct ProfileValidationTests {
    @Test(arguments: ["", "   \n", "Alex\nMorgan", String(repeating: "A", count: 61)])
    func rejectsInvalidDisplayNames(name: String) {
        #expect(throws: AccountError.invalidName) { try PlayerProfile.validatedName(name) }
    }
    @Test func trimsBeforeSavingAndSupportsUnicode() throws {
        #expect(try PlayerProfile.validatedName("  Zoë 李  ") == "Zoë 李")
    }
}
