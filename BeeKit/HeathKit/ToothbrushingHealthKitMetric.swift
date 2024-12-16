import Foundation
import HealthKit

class ToothbrushingHealthKitMetric : CategoryHealthKitMetric {
    private init(humanText: String,
                 databaseString: String,
                 category: HealthKitCategory) {
        super.init(humanText: humanText, databaseString: databaseString, category: category,
                   hkSampleType: HKObjectType.categoryType(forIdentifier: .toothbrushingEvent)!)
    }
    
    override func units(healthStore : HKHealthStore) async throws -> HKUnit {
        HKUnit.second()
    }
    
    static func make() -> ToothbrushingHealthKitMetric {
        .init(humanText: "Teethbrushing (in seconds per day)",
              databaseString: HKCategoryTypeIdentifier.toothbrushingEvent.rawValue,
              category: HealthKitCategory.SelfCare)
    }
}
