import Testing
import UIKit
@testable import ChessOTBApp

@MainActor
struct FontResourceTests {
    @Test(arguments: ["Newsreader", "DM Sans"])
    func bundledFontIsRegistered(family: String) {
        #expect(UIFont.familyNames.contains(family))
    }
    @Test(arguments: ["NewsreaderRoman-Bold", "NewsreaderRoman-SemiBold", "DMSans-9ptRegular_Regular", "DMSans-9ptRegular_Bold"])
    func typographyFaceLoadsWithoutSystemFallback(name: String) {
        #expect(UIFont(name: name, size: 17) != nil)
    }
}
