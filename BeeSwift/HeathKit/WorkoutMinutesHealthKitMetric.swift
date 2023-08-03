import Foundation
import HealthKit
import OSLog

class WorkoutMinutesHealthKitMetric : CategoryHealthKitMetric {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "WorkoutMinutesHealthKitMetric")
    let minuteInSeconds = 60.0


    init(humanText: String, databaseString: String, category: HealthKitCategory) {
        super.init(humanText: humanText, databaseString: databaseString, category: category, hkSampleType: .workoutType())
    }

    override func hkDatapointValueForSamples(samples: [HKSample], startOfDate: Date) -> Double {
        // Might also want to filter by end of day?
        let samplesOnDay = samples.filter{sample in sample.startDate >= startOfDate}
        let workouts = samplesOnDay.compactMap({sample in sample as? HKWorkout})
        let workoutMinutes = workouts.map{sample in sample.duration / minuteInSeconds}.reduce(0, +)
        return Double(workoutMinutes)
    }

    override func units(healthStore : HKHealthStore) async throws -> HKUnit {
        return HKUnit.minute()
    }
}
