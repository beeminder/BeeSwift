import Foundation
import HealthKit

class StandHoursHealthKitMetric : CategoryHealthKitMetric {
    let hourInSeconds = 3600.0

    init(humanText: String, databaseString: String, category: HealthKitCategory) {
        super.init(humanText: humanText, databaseString: databaseString, category: category, hkCategoryTypeIdentifier: .appleStandHour)
    }

    override func valueInAppropriateUnits(rawValue: Double) -> Double {
        return rawValue / hourInSeconds
    }
}
