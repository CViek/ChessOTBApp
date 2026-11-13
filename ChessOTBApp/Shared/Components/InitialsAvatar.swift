import SwiftUI

/// The enclosing identity row supplies the person's accessible name.
struct InitialsAvatar: View {
    let initials: String
    var tone: Tone = .sage
    var size: Size = .medium

    enum Tone: String, CaseIterable {
        case sage = "AvatarSage", clay = "AvatarClay", blue = "AvatarBlue", gold = "AvatarGold"
    }

    enum Size: CGFloat, CaseIterable {
        case small = 40, medium = 56, large = 90

        var fontSize: CGFloat {
            switch self {
            case .small: 12
            case .medium: 14
            case .large: 25
            }
        }
    }

    var body: some View {
        Text(initials)
            .font(.custom(size == .large ? "NewsreaderRoman-Bold" : "DMSans-9ptRegular_Bold", size: size.fontSize, relativeTo: .body))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .padding(DesignTokens.Spacing.extraSmall)
            .frame(width: size.rawValue, height: size.rawValue)
            .foregroundStyle(DesignTokens.Colors.avatarInk)
            .background(Color(tone.rawValue), in: .circle)
            .overlay(Circle().strokeBorder(DesignTokens.Colors.avatarInk.opacity(0.08), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

#Preview("Avatar sizes and tones") {
    VStack {
        ForEach(InitialsAvatar.Size.allCases, id: \.self) { size in
            HStack {
                ForEach(InitialsAvatar.Tone.allCases, id: \.self) { tone in
                    InitialsAvatar(initials: "AM", tone: tone, size: size)
                }
            }
        }
    }
    .padding().background(DesignTokens.Colors.paper)
}
