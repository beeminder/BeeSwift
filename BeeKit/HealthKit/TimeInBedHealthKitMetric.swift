import Foundation
import HealthKit
import OSLog

class TimeInBedHealthKitMetric: CategoryHealthKitMetric {
  let hourInSeconds = 3600.0

  init(humanText: String, databaseString: String, category: HealthKitCategory) {
    super.init(
      humanText: humanText,
      databaseString: databaseString,
      category: category,
      hkSampleType: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    )
  }

  override func includeForMetric(sample: HKCategorySample) -> Bool {
    return sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue
  }

  override func valueInAppropriateUnits(rawValue: Double) -> Double { return rawValue / hourInSeconds }

  override func units(healthStore: HKHealthStore) async throws -> HKUnit { return HKUnit.hour() }
}
