import Foundation
import HealthKit
import OSLog

public class WeightHealthKitMetric: QuantityHealthKitMetric {
  private let weightLogger = Logger(subsystem: "com.beeminder.beeminder", category: "WeightHealthKitMetric")

  public override var hasAdditionalOptions: Bool { true }

  public init(humanText: String, databaseString: String, category: HealthKitCategory) {
    super.init(
      humanText: humanText,
      databaseString: databaseString,
      category: category,
      hkQuantityTypeIdentifier: .bodyMass,
      precision: [HKUnit.pound(): 1, HKUnit.gramUnit(with: .kilo): 2]
    )
  }

  public override func recentDataPoints(
    days: Int,
    deadline: Int,
    healthStore: HKHealthStore,
    autodataConfig: [String: Any]
  ) async throws -> [BeeDataPoint] {
    let dailyAggregate = autodataConfig["daily_aggregate"] as? Bool ?? true
    if dailyAggregate {
      return try await super.recentDataPoints(
        days: days,
        deadline: deadline,
        healthStore: healthStore,
        autodataConfig: autodataConfig
      )
    } else {
      return try await individualWeightDataPoints(days: days, deadline: deadline, healthStore: healthStore)
    }
  }

  private func individualWeightDataPoints(days: Int, deadline: Int, healthStore: HKHealthStore) async throws
    -> [BeeDataPoint]
  {
    let today = Daystamp.now(deadline: deadline)
    let startDate = today - days
    var results: [BeeDataPoint] = []

    let unit = try await units(healthStore: healthStore)

    for date in (startDate...today) {
      let samples = try await getWeightSamples(date: date, deadline: deadline, healthStore: healthStore)
      for sample in samples {
        let weightValue = applyPrecision(value: sample.quantity.doubleValue(for: unit), unit: unit)
        let timeString = formatSampleTime(sample: sample)
        let sourceName = sample.sourceRevision.source.name
        let id = "apple-health-weight-\(sample.uuid.uuidString)"
        results.append(
          NewDataPoint(
            requestid: id,
            daystamp: date,
            value: NSNumber(value: weightValue),
            comment: "Weight via \(sourceName) at \(timeString)"
          )
        )
      }
    }
    return results
  }

  private func getWeightSamples(date: Daystamp, deadline: Int, healthStore: HKHealthStore) async throws
    -> [HKQuantitySample]
  {
    guard let quantityType = HKObjectType.quantityType(forIdentifier: hkQuantityTypeIdentifier) else {
      throw HealthKitError("Unable to look up weight quantity type")
    }

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
      let query = HKSampleQuery(
        sampleType: quantityType,
        predicate: HKQuery.predicateForSamples(
          withStart: date.start(deadline: deadline),
          end: date.end(deadline: deadline)
        ),
        limit: 0,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)],
        resultsHandler: { (query, samples, error) in
          if let error = error {
            continuation.resume(throwing: error)
          } else if let samples = samples as? [HKQuantitySample] {
            continuation.resume(returning: samples)
          } else {
            continuation.resume(returning: [])
          }
        }
      )
      healthStore.execute(query)
    }
  }

  private func formatSampleTime(sample: HKQuantitySample) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: sample.startDate)
  }
}
