import Combine
import Foundation

@MainActor final class RadiusInputViewModel: ObservableObject {
    @Published var text: String {
        didSet { if let radius { lastValidRadius = radius } }
    }
    private var lastValidRadius: SearchRadius
    init(radius: SearchRadius) { text = String(radius.rawValue); lastValidRadius = radius }
    var radius: SearchRadius? {
        guard let miles = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return SearchRadius(rawValue: miles)
    }
    var errorMessage: String? { radius == nil ? String(localized: "Enter a whole number from 1 to 100 miles.") : nil }
    var sliderLabel: String {
        lastValidRadius.rawValue == 1 ? String(localized: "1 mile") : String(localized: "\(lastValidRadius.rawValue) miles")
    }
    var sliderValue: Double {
        get { Double(lastValidRadius.rawValue) }
        set {
            guard newValue.isFinite else { return }
            let bounded = min(Double(SearchRadius.allowedRange.upperBound), max(Double(SearchRadius.allowedRange.lowerBound), newValue.rounded()))
            text = String(Int(bounded))
        }
    }
    func reset() { text = String(SearchRadius.five.rawValue) }
}
