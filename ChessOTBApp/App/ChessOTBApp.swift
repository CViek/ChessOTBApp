import SwiftUI

@main
struct ChessOTBApp: App {
    private let dependencies: AppDependencies
    @State private var session: SessionViewModel
    @State private var appearance = AppearanceSettings()

    init() {
        let dependencies = AppDependencies.live()
        self.dependencies = dependencies
        _session = State(initialValue: SessionViewModel(auth: dependencies.auth))
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .environment(session)
                .environment(appearance)
                .tint(DesignTokens.Colors.forest)
                .font(DesignTokens.Typography.body)
                .preferredColorScheme(appearance.darkOverride.map { $0 ? .dark : .light })
        }
    }
}
