import SwiftUI

@main
struct ChessOTBApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(DesignTokens.Colors.forest)
                .font(DesignTokens.Typography.body)
        }
    }
}
