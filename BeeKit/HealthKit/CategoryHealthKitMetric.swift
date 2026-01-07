//  CategoryHealthKitMetric.swift
//  BeeSwift
//
//  A HealthKit metric represented by `HkCategorySample`s and must be manually
//  converted to metrics by the app

import Foundation
import HealthKit
import OSLog

public class CategoryHealthKitMetric: HealthKitMetric {
  private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "CategoryHealthKitMetric")

  public let humanText: String
  public let databaseString: String
  public let category: HealthKitCategory
  public var hasAdditionalOptions: Bool { false }
  let hkSampleType: HKSampleType

  internal init(humanText: String, databaseString: String, category: HealthKitCategory, hkSampleType: HKSampleType) {
    self.humanText = humanText
    self.databaseString = databaseString
    self.category = category
    self.hkSampleType = hkSampleType
  }

  public func sampleType() -> HKSampleType { return hkSampleType }

  public func permissionType() -> HKObjectType { return hkSampleType }

  public func recentDataPoints(days: Int, deadline: Int, healthStore: HKHealthStore, autodataConfig: [String: Any])
    async throws -> [BeeDataPoint]
  {
    let today = Daystamp.now(deadline: deadline)
    let startDate = today - days

    var results: [BeeDataPoint] = []
    for date in (startDate...today) {
      results.append(try await self.getDataPoint(date: date, deadline: deadline, healthStore: healthStore))
    }
    return results
  }

  public func units(healthStore: HKHealthStore) async throws -> HKUnit { return HKUnit.count() }

  private func getDataPoint(date: Daystamp, deadline: Int, healthStore: HKHealthStore) async throws -> BeeDataPoint {

    let samples = try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<[HKSample], Error>) in
      let query = HKSampleQuery(
        sampleType: sampleType(),
        predicate: HKQuery.predicateForSamples(
          withStart: date.start(deadline: deadline),
          end: date.end(deadline: deadline)
        ),
        limit: 0,
        sortDescriptors: nil,
        resultsHandler: { (query, samples, error) in
          if error != nil {
            continuation.resume(throwing: error!)
          } else if samples == nil {
            continuation.resume(throwing: HealthKitError("HKSampleQuery did not return samples"))
          } else {
            continuation.resume(returning: samples!)
          }
        }
      )
      healthStore.execute(query)
    })

    let id = "apple-heath-" + date.description
    let datapointValue = self.hkDatapointValueForSamples(samples: samples, startOfDate: date.start(deadline: deadline))
    return NewDataPoint(
      requestid: id,
      daystamp: date,
      value: NSNumber(value: datapointValue),
      comment: "Auto-entered via Apple Health"
    )
  }

  /// Predict to filter samples to those relevant to this metric, for cases where with cannot be encoded in the healthkit query
  internal func includeForMetric(sample: HKCategorySample) -> Bool { return true }

  /// Converts the raw aggregate value to appropiate units. e.g. to report in hours rather than seconds
  internal func valueInAppropriateUnits(rawValue: Double) -> Double { return rawValue }

  func hkDatapointValueForSamples(samples: [HKSample], startOfDate: Date) -> Double {
    let relevantSamples = samples.compactMap { $0 as? HKCategorySample }.sorted { $0.startDate < $1.startDate }

    var aggregateTime: Double = 0
    var timeReached: Date? = nil

    func roundedToNearestMinute(_ date: Date) -> Date {
      let minuteInSeconds = 60.0
      return Date(
        timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / minuteInSeconds).rounded(
          .toNearestOrEven
        ) * minuteInSeconds
      )
    }

    for sample in relevantSamples {
      let startDate = roundedToNearestMinute(sample.startDate)
      let endDate = roundedToNearestMinute(sample.endDate)

      if timeReached == nil || timeReached! < startDate {
        // Sample does not overlap previous range, include entire value plus one for starting minute
        // Notes: This off-by-one adjustment seems to generally produce better data for Oura, but worse
        //        data for apple watch. Unclear why or what is different. Maybe to do with transitions between
        //        stages?
        //        Apple watch sends *Awake* intervals. Which we aren't logging because we are filtering them out.
        //        But it looks like they change fencepost behavior, maybe because they provide continuity?
        //        This filter is wrong because with multiple sources asleep can overlap with awake, and we should not just
        //        ignore the later asleep time. But maybe we should avoid fenceposting while in that time?
        if self.includeForMetric(sample: sample) { aggregateTime += endDate.timeIntervalSince(startDate) + 60.0 }
        timeReached = endDate
      } else if timeReached! < endDate {
        // Sample overlaps but extends previous range, add non-overlapping portion
        if self.includeForMetric(sample: sample) { aggregateTime += endDate.timeIntervalSince(timeReached!) }
        timeReached = endDate
      } else {
        // Sample is within previous range, do nothing
      }
    }

    return valueInAppropriateUnits(rawValue: aggregateTime)
  }
}
