// Part of BeeSwift. Copyright Beeminder

import Foundation
import HealthKit

/// tracks toothbrushing, in number of sessions per day (daystamp)
class ToothbrushingDailySessionsHealthKitMetric: CategoryHealthKitMetric {
    private static let healthkitMetric =  ["toothbrushing", "sessions-per-day"].joined(separator: "|")
    private static let hkSampleType = HKObjectType.categoryType(forIdentifier: .toothbrushingEvent)!
    
    init(humanText: String = "Teethbrushing (in sessions per day)",
         databaseString: String = ToothbrushingDailySessionsHealthKitMetric.healthkitMetric,
         category: HealthKitCategory = .Other) {
        super.init(humanText: humanText,
                   databaseString: databaseString,
                   category: category,
                   hkSampleType: Self.hkSampleType)
    }
    
    override func units(healthStore : HKHealthStore) async throws -> HKUnit {
        .count()
    }
    
    override func recentDataPoints(days: Int, deadline: Int, healthStore: HKHealthStore) async throws -> [any BeeDataPoint] {
        let todayDaystamp = Daystamp.now(deadline: deadline)
        let startDaystamp = todayDaystamp - days
        
        let predicate = HKQuery.predicateForSamples(withStart: startDaystamp.start(deadline: deadline),
                                                    end: todayDaystamp.end(deadline: deadline))
        
        let samples = try await queryHealthStore(healthStore, predicate: predicate)
        
        let dailyCounts = calculateDailyCounts(samples: samples)
        
        let datapoints = makeDatapoints(dailyCounts: dailyCounts, deadline: deadline)
        
        return datapoints
    }
    
    func queryHealthStore(_ healthStore: HKHealthStore, predicate: NSPredicate) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: sampleType(),
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)],
                                      resultsHandler: { (query, samples, error) in
                if let error {
                    continuation.resume(throwing: error)
                } else if let samples {
                    continuation.resume(returning: samples)
                } else {
                    continuation.resume(throwing: HealthKitError("HKSampleQuery did not return samples"))
                }
            })
            healthStore.execute(query)
        })
            .compactMap { $0 as? HKCategorySample }
    }
    
    func calculateDailyCounts(samples: [HKCategorySample]) -> [(Date, Int)] {
        let calendar = Calendar.autoupdatingCurrent
        let groupedByDay = Dictionary(grouping: samples, by: { sample in
            calendar.startOfDay(for: sample.startDate)
        })
        
        let dailyCounts = groupedByDay
            .map { ($0, $1.count) }
            .sorted { $0.0 < $1.0 }
        
        return dailyCounts
    }
    
    func makeDatapoints(dailyCounts: [(Date, Int)], deadline: Int) -> [any BeeDataPoint] {
        let datapoints = dailyCounts.map({ (date, numberOfEntries) in
            let daystamp = Daystamp(fromDate: date, deadline: deadline)
            let requestID = "apple-heath-" + daystamp.description
            
            return NewDataPoint(requestid: requestID,
                                daystamp: daystamp,
                                value: NSNumber(value: numberOfEntries),
                                comment: "Auto-entered via Apple Health (\(Self.healthkitMetric))")
        })
        
        return datapoints
    }
}
