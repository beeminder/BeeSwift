import Foundation
import HealthKit

class MindfulSessionHealthKitMetric : CategoryHealthKitMetric {
    let minuteInSeconds = 60.0

    init(humanText: String, databaseString: String, category: HealthKitCategory) {
        super.init(humanText: humanText, databaseString: databaseString, category: category, hkSampleType: HKObjectType.categoryType(forIdentifier: .mindfulSession)!)
    }

    override func valueInAppropriateUnits(rawValue: Double) -> Double {
        return rawValue / minuteInSeconds
    }

    override func units(healthStore : HKHealthStore) async throws -> HKUnit {
        return HKUnit.minute()
    }
}
