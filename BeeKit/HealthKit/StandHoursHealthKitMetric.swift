import Foundation
import HealthKit
import OSLog

class StandHoursHealthKitMetric: CategoryHealthKitMetric {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "StandHoursHealthKitMetric")

  init(humanText: String, databaseString: String, category: HealthKitCategory) {
    super.init(
      humanText: humanText,
      databaseString: databaseString,
      category: category,
      hkSampleType: HKObjectType.categoryType(forIdentifier: .appleStandHour)!
    )
  }

  override func hkDatapointValueForSamples(samples: [HKSample], startOfDate: Date) -> Double {
    // The query gives us all data points which touch our filter range. This includes the very end of the last day, as it ends
    // at midnight, so we must filter it out
    let samplesOnDay = samples.filter { sample in sample.startDate >= startOfDate }
    let categorySamples = samplesOnDay.compactMap({ sample in sample as? HKCategorySample })
    let standingSamples = categorySamples.filter { sample in
      sample.value == HKCategoryValueAppleStandHour.stood.rawValue
    }
    return Double(standingSamples.count)
  }

  override func units(healthStore: HKHealthStore) async throws -> HKUnit { return HKUnit.count() }
}
