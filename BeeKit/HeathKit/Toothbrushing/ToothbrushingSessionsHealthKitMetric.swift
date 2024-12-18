// Part of BeeSwift. Copyright Beeminder

import Foundation
import HealthKit

/// tracks toothbrushing, in number of sessions per day (daystamp)
class ToothbrushingSessionsHealthKitMetric: CategoryHealthKitMetric {
    private static let healthkitMetric =  ["toothbrushing", "sessions-per-day"].joined(separator: "|")
    
    private init(humanText: String,
                 databaseString: String,
                 category: HealthKitCategory) {
        super.init(humanText: humanText,
                   databaseString: databaseString,
                   category: category,
                   hkSampleType: HKObjectType.categoryType(forIdentifier: .toothbrushingEvent)!)
    }
    
    override func units(healthStore : HKHealthStore) async throws -> HKUnit {
        .count()
    }
    
    static func make() -> ToothbrushingSessionsHealthKitMetric {
        .init(humanText: "Teethbrushing (in sessions per day)",
              databaseString: healthkitMetric,
              category: HealthKitCategory.SelfCare)
    }
    
    override func recentDataPoints(days: Int, deadline: Int, healthStore: HKHealthStore) async throws -> [any BeeDataPoint] {
        let todayDaystamp = Daystamp.now(deadline: deadline)
        let startDaystamp = todayDaystamp - days
        
        let predicate = HKQuery.predicateForSamples(withStart: startDaystamp.start(deadline: deadline),
                                                    end: todayDaystamp.end(deadline: deadline))
        
        let samples = try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<[HKSample], Error>) in
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
        
        let calendar = Calendar.autoupdatingCurrent
        let groupedByDay = Dictionary(grouping: samples, by: { sample in
            calendar.startOfDay(for: sample.startDate)
        })
        
        let dailyCounts = groupedByDay
            .map { ($0, $1.count) }
            .sorted { $0.0 < $1.0 }
        
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
