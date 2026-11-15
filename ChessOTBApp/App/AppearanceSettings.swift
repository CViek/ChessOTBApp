import Foundation
import Observation

@MainActor
@Observable
final class AppearanceSettings {
    private(set) var darkOverride: Bool?
    private let defaults: UserDefaults
    private let key = "prefersDarkAppearance"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        darkOverride = defaults.object(forKey: key) as? Bool
    }

    func setDarkAppearance(_ enabled: Bool) {
        darkOverride = enabled
        defaults.set(enabled, forKey: key)
    }
}
