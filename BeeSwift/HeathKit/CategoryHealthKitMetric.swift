//  CategoryHealthKitMetric.swift
//  BeeSwift
//
//  A HealthKit metric represented by `HkCategorySample`s and must be manually
//  converted to metrics by the app

import Foundation
import HealthKit
import OSLog

class CategoryHealthKitMetric : HealthKitMetric {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "CategoryHealthKitMetric")

    let humanText : String
    let databaseString : String
    let category : HealthKitCategory
    let hkSampleType : HKSampleType

    internal init(humanText: String, databaseString: String, category : HealthKitCategory, hkSampleType: HKSampleType) {
        self.humanText = humanText
        self.databaseString = databaseString
        self.category = category
        self.hkSampleType = hkSampleType
    }

    func sampleType() -> HKSampleType {
        return hkSampleType
    }

    func permissionType() -> HKObjectType {
        return hkSampleType
    }

    func recentDataPoints(days : Int, deadline : Int, healthStore : HKHealthStore) async throws -> [DataPoint] {
        var results : [DataPoint] = []
        for dayOffset in ((-1*days + 1)...0) {
            results.append(try await self.getDataPoint(dayOffset: dayOffset, deadline: deadline, healthStore: healthStore))
        }
        return results
    }

    func units(healthStore : HKHealthStore) async throws -> HKUnit {
        return HKUnit.count()
    }

    private func getDataPoint(dayOffset : Int, deadline : Int, healthStore : HKHealthStore) async throws -> DataPoint {
        let bounds = try dateBoundsForDayOffset(dayOffset: dayOffset, deadline: deadline)
        let daystamp = try self.dayStampFromDayOffset(dayOffset: dayOffset, deadline: deadline)

        let samples = try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery.init(
                sampleType: sampleType(),
                predicate: HKQuery.predicateForSamples(withStart: bounds.start, end: bounds.end),
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
            })
            healthStore.execute(query)
        })

        let datapointValue = self.hkDatapointValueForSamples(samples: samples, startOfDate: bounds.start)
        return NewDataPoint(daystamp: daystamp, value: NSNumber(value: datapointValue), comment: "Auto-entered via Apple Health")
    }

    internal func dayStampFromDayOffset(dayOffset : Int, deadline : Int) throws -> String {
        let bounds = try self.dateBoundsForDayOffset(dayOffset: dayOffset, deadline: deadline)
        let datapointDate = deadline >= 0 ? bounds.start : bounds.end

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: datapointDate)
    }

    func dateBoundsForDayOffset(dayOffset : Int, deadline : Int) throws -> (start: Date, end: Date) {
        let calendar = Calendar.current

        let components = calendar.dateComponents(in: TimeZone.current, from: Date())
        let localMidnightThisMorning = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(from: components)!)
        let localMidnightTonight = calendar.date(byAdding: .day, value: 1, to: localMidnightThisMorning!)

        let endOfToday = calendar.date(byAdding: .second, value: deadline, to: localMidnightTonight!)
        let startOfToday = calendar.date(byAdding: .second, value: deadline, to: localMidnightThisMorning!)

        guard let startDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday!) else { throw HealthKitError("Could not calculate start date") }
        guard let endDate = calendar.date(byAdding: .day, value: dayOffset, to: endOfToday!) else { throw HealthKitError("Could not calculate end date") }

        return (start: startDate, end: endDate)
    }

    /// Predict to filter samples to those relevant to this metric, for cases where with cannot be encoded in the healthkit query
    internal func includeForMetric(sample: HKCategorySample) -> Bool {
        return true
    }

    /// Converts the raw aggregate value to appropiate units. e.g. to report in hours rather than seconds
    internal func valueInAppropriateUnits(rawValue: Double) -> Double {
        return rawValue
    }

    func hkDatapointValueForSamples(samples: [HKSample], startOfDate: Date) -> Double {
        let relevantSamples = samples
            .compactMap { $0 as? HKCategorySample }
            .sorted { $0.startDate < $1.startDate }

        var aggregateTime : Double = 0
        var timeReached : Date? = nil

        func roundedToNearestMinute(_ date: Date) -> Date {
            let minuteInSeconds = 60.0
            return Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / minuteInSeconds).rounded(.toNearestOrEven) * minuteInSeconds)
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
                if self.includeForMetric(sample: sample) {
                    aggregateTime += endDate.timeIntervalSince(startDate) + 60.0
                }
                timeReached = endDate
            } else if timeReached! < endDate {
                // Sample overlaps but extends previous range, add non-overlapping portion
                if self.includeForMetric(sample: sample) {
                    aggregateTime += endDate.timeIntervalSince(timeReached!)
                }
                timeReached = endDate
            } else {
                // Sample is within previous range, do nothing
            }
        }

        return valueInAppropriateUnits(rawValue: aggregateTime)
    }
}
