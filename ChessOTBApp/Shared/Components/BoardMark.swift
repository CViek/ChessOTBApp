import SwiftUI

/// The native 2×2 geometric mark from Figma's .board-mark, without device chrome.
struct BoardMark: View {
    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Rectangle().fill(DesignTokens.Colors.forest)
                Rectangle().fill(.clear)
            }
            GridRow {
                Rectangle().fill(.clear)
                Rectangle().fill(DesignTokens.Colors.forest)
            }
        }
        .frame(width: DesignTokens.Size.boardMark, height: DesignTokens.Size.boardMark)
        .overlay(Rectangle().strokeBorder(DesignTokens.Colors.forest, lineWidth: 2))
        .rotationEffect(.degrees(-2))
        .accessibilityHidden(true)
    }
}

#Preview {
    BoardMark().padding().background(DesignTokens.Colors.paper)
}
