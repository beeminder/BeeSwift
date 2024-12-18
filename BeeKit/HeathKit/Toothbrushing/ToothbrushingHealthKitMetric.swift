import Foundation
import HealthKit

/// tracks toothbrushing, in number of seconds per day (daystamp)
class ToothbrushingHealthKitMetric: CategoryHealthKitMetric {
    private static let healthkitMetric = ["toothbrushing", "seconds-per-day"].joined(separator: "|")
    
    private init(humanText: String,
                 databaseString: String,
                 category: HealthKitCategory) {
        super.init(humanText: humanText,
                   databaseString: databaseString,
                   category: category,
                   hkSampleType: HKObjectType.categoryType(forIdentifier: .toothbrushingEvent)!)
    }
    
    override func units(healthStore : HKHealthStore) async throws -> HKUnit {
        HKUnit.second()
    }
    
    static func make() -> ToothbrushingHealthKitMetric {
        .init(humanText: "Teethbrushing (in seconds per day)",
              databaseString: healthkitMetric,
              category: HealthKitCategory.SelfCare)
    }
    
    override func recentDataPoints(days: Int, deadline: Int, healthStore: HKHealthStore) async throws -> [any BeeDataPoint] {
        try await super.recentDataPoints(days: days, deadline: deadline, healthStore: healthStore)
            .map {
                NewDataPoint(requestid: $0.requestid,
                             daystamp: $0.daystamp,
                             value: $0.value,
                             comment: "Auto-entered via Apple Health (\(Self.healthkitMetric))")
            }
    }
}
