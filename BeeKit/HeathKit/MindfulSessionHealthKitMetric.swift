import Foundation
import HealthKit

class MindfulSessionHealthKitMetric : CategoryHealthKitMetric {
    let minuteInSeconds = 60.0

    init(humanText: String, databaseString: String, category: HealthKitCategory) {
        super.init(humanText: humanText, databaseString: databaseString, category: category, hkSampleType: HKObjectType.categoryType(forIdentifier: .mindfulSession)!)
    }

    override func hkDatapointValueForSamples(samples: [HKSample], startOfDate: Date) -> Double {
        let endOfDate = startOfDate.addingTimeInterval(24 * 60 * 60)

        let orderedSamples = samples.sorted(by: { $0.startDate < $1.startDate })

        var spanStart: Optional<Date> = nil
        var spanEnd: Optional<Date> = nil
        var totalSeconds = 0.0

        for sample in orderedSamples {
            if sample.hasUndeterminedDuration {
                continue
            }

            let sampleStart = max(sample.startDate, startOfDate)
            let sampleEnd = min(sample.endDate, endOfDate)

            if let start = spanStart, let end = spanEnd {
                // There is an existing span to examine
                if sampleStart <= end {
                    // If the sample overlaps with the current span, extend the span
                    spanEnd = max(end, sampleEnd)
                } else {
                    // Otherwise, add the span to the total and start a new span
                    totalSeconds += end.timeIntervalSince(start)
                    spanStart = sampleStart
                    spanEnd = sampleEnd
                }
            } else {
                // No prior span, start with this one
                spanStart = sampleStart
                spanEnd = sampleEnd
            }
        }
        if let end = spanEnd {
            totalSeconds += end.timeIntervalSince(spanStart!)
        }

        let totalMinutes = totalSeconds / minuteInSeconds
        return totalMinutes.rounded()
    }

    override func units(healthStore : HKHealthStore) async throws -> HKUnit {
        return HKUnit.minute()
    }
}
