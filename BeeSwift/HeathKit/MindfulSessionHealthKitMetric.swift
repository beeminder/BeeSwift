import Foundation
import HealthKit

class MindfulSessionHealthKitMetric : CategoryHealthKitMetric {
    let minuteInSeconds = 60.0

    init(humanText: String, databaseString: String, category: HealthKitCategory) {
        super.init(humanText: humanText, databaseString: databaseString, category: category, hkCategoryTypeIdentifier: .mindfulSession)
    }

    override func valueInAppropriateUnits(rawValue: Double) -> Double {
        return rawValue / minuteInSeconds
    }
}
