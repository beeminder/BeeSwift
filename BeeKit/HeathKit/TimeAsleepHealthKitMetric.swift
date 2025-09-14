import Foundation
import HealthKit
import OSLog

class TimeAsleepHealthKitMetric: CategoryHealthKitMetric {
  let hourInMinutes = 60.0

  init(humanText: String, databaseString: String, category: HealthKitCategory) {
    super.init(
      humanText: humanText,
      databaseString: databaseString,
      category: category,
      hkSampleType: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    )
  }

  override func hkDatapointValueForSamples(samples: [HKSample], startOfDate: Date) -> Double {
    let categorySamples = samples.compactMap { sample in sample as? HKCategorySample }
    let totalMinutes = totalSleepMinutes(samples: categorySamples)
    return Double(totalMinutes) / hourInMinutes
  }

  override func units(healthStore: HKHealthStore) async throws -> HKUnit { return HKUnit.hour() }
}
