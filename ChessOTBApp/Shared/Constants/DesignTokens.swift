import SwiftUI

/// Verified against Figma Make src/index.css. Colors resolve through light/dark assets.
enum DesignTokens {
    enum Colors {
        static let paper = Color("Paper")
        static let surface = Color("Surface")
        static let ink = Color("Ink")
        static let muted = Color("Muted")
        static let line = Color("Line")
        static let forest = Color("Forest")
        static let forestSecondary = Color("ForestSecondary")
        static let oxblood = Color("Oxblood")
        static let sage = Color("Sage")
        static let amber = Color("Amber")
        static let success = Color("Success")
        static let danger = Color("Danger")
        static let avatarInk = Color("AvatarInk")
        static let notationPaper = Color("NotationPaper")
        static let slipBorder = Color("SlipBorder")
        static let reviewBorder = Color("ReviewBorder")
    }

    enum Typography {
        static let setupTitle = Font.custom("NewsreaderRoman-Bold", size: 39, relativeTo: .largeTitle)
        static let listTitle = Font.custom("NewsreaderRoman-Bold", size: 36, relativeTo: .largeTitle)
        static let playerTitle = Font.custom("NewsreaderRoman-Bold", size: 32, relativeTo: .title)
        static let groupTitle = Font.custom("NewsreaderRoman-Bold", size: 31, relativeTo: .title)
        static let sectionTitle = Font.custom("NewsreaderRoman-SemiBold", size: 24, relativeTo: .title2)
        static let statusTitle = Font.custom("NewsreaderRoman-SemiBold", size: 25, relativeTo: .title2)
        static let body = Font.custom("DMSans-9ptRegular_Regular", size: 17, relativeTo: .body)
        static let control = Font.custom("DMSans-9ptRegular_Bold", size: 16, relativeTo: .body)
        static let eyebrow = Font.custom("DMSans-9ptRegular_Bold", size: 15, relativeTo: .subheadline)
        static let notice = Font.custom("DMSans-9ptRegular_Regular", size: 14, relativeTo: .subheadline)
        static let caption = Font.custom("DMSans-9ptRegular_Regular", size: 13, relativeTo: .footnote)
    }

    enum Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let regular: CGFloat = 16
        static let pageInset: CGFloat = 22
        static let setupInset: CGFloat = 28
        static let large: CGFloat = 24
    }

    enum Radius {
        static let action: CGFloat = 12
        static let field: CGFloat = 10
        static let segmented: CGFloat = 9
        static let segmentedSelection: CGFloat = 7
        static let areaControl: CGFloat = 11
        static let meetingCard: CGFloat = 12
        static let previousDetails: CGFloat = 8
        static let proposalSlip: CGFloat = 3
    }

    enum Size {
        static let controlHeight: CGFloat = 50
        static let minimumTapTarget: CGFloat = 44
        static let areaControl: CGFloat = 56
        static let boardMark: CGFloat = 72
    }
}
