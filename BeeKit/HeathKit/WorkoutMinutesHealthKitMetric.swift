import Foundation
import HealthKit
import OSLog

public class WorkoutMinutesHealthKitMetric : CategoryHealthKitMetric {
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
    
    public override func recentDataPoints(days: Int, deadline: Int, healthStore: HKHealthStore, autodataConfig: [String: Any]?) async throws -> [BeeDataPoint] {
        let dailyAggregate = autodataConfig?["daily_aggregate"] as? Bool ?? true
        
        if !dailyAggregate {
            return try await individualWorkoutDataPoints(days: days, deadline: deadline, healthStore: healthStore)
        } else {
            return try await super.recentDataPoints(days: days, deadline: deadline, healthStore: healthStore, autodataConfig: autodataConfig)
        }
    }
    
    func individualWorkoutDataPoints(days: Int, deadline: Int, healthStore: HKHealthStore) async throws -> [BeeDataPoint] {
        let today = Daystamp.now(deadline: deadline)
        let startDate = today - days
        
        var results: [BeeDataPoint] = []
        
        for date in (startDate...today) {
            let samples = try await getWorkoutSamples(date: date, deadline: deadline, healthStore: healthStore)
            let workouts = samples.compactMap { $0 as? HKWorkout }
            
            for workout in workouts {
                let workoutMinutes = workout.duration / minuteInSeconds
                let workoutDescription = formatWorkoutDescription(workout: workout)
                let id = "apple-health-workout-\(workout.uuid.uuidString)"
                
                results.append(NewDataPoint(
                    requestid: id,
                    daystamp: date,
                    value: NSNumber(value: workoutMinutes),
                    comment: workoutDescription
                ))
            }
        }
        
        return results
    }
    
    private func getWorkoutSamples(date: Daystamp, deadline: Int, healthStore: HKHealthStore) async throws -> [HKSample] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(
                sampleType: sampleType(),
                predicate: HKQuery.predicateForSamples(withStart: date.start(deadline: deadline), end: date.end(deadline: deadline)),
                limit: 0,
                sortDescriptors: nil,
                resultsHandler: { (query, samples, error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let samples = samples {
                        continuation.resume(returning: samples)
                    } else {
                        continuation.resume(throwing: HealthKitError("HKSampleQuery did not return samples"))
                    }
                }
            )
            healthStore.execute(query)
        }
    }
    
    private func formatWorkoutDescription(workout: HKWorkout) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: workout.startDate)
        
        let activityName = workoutActivityTypeName(for: workout.workoutActivityType)
        
        return "\(activityName) at \(timeString)"
    }
    
    private func workoutActivityTypeName(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .swimming:
            return "Swimming"
        case .yoga:
            return "Yoga"
        case .traditionalStrengthTraining:
            return "Traditional Strength Training"
        case .coreTraining:
            return "Core Training"
        case .elliptical:
            return "Elliptical"
        case .rowing:
            return "Rowing"
        case .hiking:
            return "Hiking"
        case .dance:
            return "Dance"
        case .tennis:
            return "Tennis"
        case .basketball:
            return "Basketball"
        case .soccer:
            return "Soccer"
        case .americanFootball:
            return "American Football"
        case .baseball:
            return "Baseball"
        case .golf:
            return "Golf"
        case .pilates:
            return "Pilates"
        case .martialArts:
            return "Martial Arts"
        case .boxing:
            return "Boxing"
        case .climbing:
            return "Climbing"
        case .crossTraining:
            return "Cross Training"
        case .functionalStrengthTraining:
            return "Functional Strength Training"
        case .mixedCardio:
            return "Mixed Cardio"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .jumpRope:
            return "Jump Rope"
        case .stairClimbing:
            return "Stair Climbing"
        case .snowSports:
            return "Snow Sports"
        case .waterSports:
            return "Water Sports"
        case .wrestling:
            return "Wrestling"
        case .volleyball:
            return "Volleyball"
        case .hockey:
            return "Hockey"
        case .rugby:
            return "Rugby"
        case .cricket:
            return "Cricket"
        case .archery:
            return "Archery"
        case .bowling:
            return "Bowling"
        case .fishing:
            return "Fishing"
        case .hunting:
            return "Hunting"
        case .lacrosse:
            return "Lacrosse"
        case .paddleSports:
            return "Paddle Sports"
        case .racquetball:
            return "Racquetball"
        case .softball:
            return "Softball"
        case .squash:
            return "Squash"
        case .tableTennis:
            return "Table Tennis"
        case .trackAndField:
            return "Track And Field"
        case .badminton:
            return "Badminton"
        case .barre:
            return "Barre"
        case .cooldown:
            return "Cool Down"
        case .flexibility:
            return "Flexibility"
        case .mindAndBody:
            return "Mind And Body"
        case .preparationAndRecovery:
            return "Preparation And Recovery"
        case .waterFitness:
            return "Water Fitness"
        default:
            return "Workout"
        }
    }

    public override func units(healthStore : HKHealthStore) async throws -> HKUnit {
        return HKUnit.minute()
    }
}
