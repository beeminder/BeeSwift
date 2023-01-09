//
//  TimeAsleep.swift
//  BeeSwift
//
//  Created by Theo Spears on 1/8/23.
//  Copyright © 2023 APB. All rights reserved.
//

import Foundation
import HealthKit

/// The timestamp corresponding to the start of a minute
typealias Minute = Int

func minute(_ date: Date) -> Minute {
    // FIXME: Does this truncate?
    return Int(date.timeIntervalSince1970 - date.timeIntervalSince1970.truncatingRemainder(dividingBy: 60))
}

enum SleepResolution {
    case asleep, awake, ambiguous
}

func sleepResolution<S: Sequence<HKCategorySample>>(minute: Minute, samples: S) -> SleepResolution {
    let minuteEnds = minute + 60

    var totalAsleepSeconds = 0
    var totalAwakeSeconds = 0

    for sample in samples {
        let start = max(Int(sample.startDate.timeIntervalSince1970), minute)
        let end = min(Int(sample.endDate.timeIntervalSince1970), minuteEnds)
        let duration = end - start

        if isAsleep(sample) {
            totalAsleepSeconds += duration
        } else {
            totalAwakeSeconds += duration
        }
    }

    if totalAwakeSeconds < totalAsleepSeconds {
        return SleepResolution.asleep
    } else if totalAwakeSeconds == totalAsleepSeconds {
        return SleepResolution.ambiguous
    } else {
        return SleepResolution.awake
    }
}

func wouldFirstMinuteBeAsleep<S: Sequence<HKCategorySample>>(samples: S) -> Bool {
    let firstMinute = minute(samples.map{sample in sample.startDate}.min()!)
    let samplesStartingInFirstMinute = samples.filter{sample in minute(sample.startDate) == firstMinute}

    let resolutionForFirstMinute = sleepResolution(minute: firstMinute,  samples: samplesStartingInFirstMinute)
    if resolutionForFirstMinute == .asleep || resolutionForFirstMinute == .ambiguous {
        return true
    } else {
        return false
    }
}

func isAsleep(_ sample: HKCategorySample) -> Bool {
    if #available(iOS 16.0, *) {
        return HKCategoryValueSleepAnalysis.allAsleepValues.contains(HKCategoryValueSleepAnalysis(rawValue: sample.value)!)
    } else {
        // Fallback on earlier versions
        return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
    }
}

public func totalSleepMinutes(samples: [HKCategorySample]) -> Int {
    var sampleStarts: [Minute: [HKCategorySample]] = [:]
    var sampleEnds: [Minute: [HKCategorySample]] = [:]
    var minutesOfInterest: Set<Minute> = []

    for sample in samples {
        let startMinute = minute(sample.startDate)
        sampleStarts[startMinute, default: []].append(sample)
        minutesOfInterest.insert(startMinute)

        // FIXME: Off by one adjustment
        let endMinute = minute(sample.endDate)
        sampleEnds[endMinute, default: []].append(sample)
        minutesOfInterest.insert(endMinute)
    }

    var totalSleepMinutes = 0
    var activeSamples: Set<HKCategorySample> = []
    var lastMinuteProcessed: Minute = 0

    for activeMinute in minutesOfInterest.sorted() {
        // FIXME: Increment for previous minutes

        // Add all sleep for the period starting after the last minute we considered,
        // up to but not including the current minute. This could be a period of length
        //zero. We know no spans started or stopped in this interval.
        if activeSamples.count > 0 {
            let asleepSampleCount = activeSamples.filter(isAsleep).count
            let awakeSampleCount = activeSamples.filter{sample in !isAsleep(sample)}.count
            if asleepSampleCount > awakeSampleCount ||
                (asleepSampleCount == awakeSampleCount && wouldFirstMinuteBeAsleep(samples: activeSamples)) {

                totalSleepMinutes += (activeMinute - lastMinuteProcessed) / 60 - 1
            }
        }

        for sample in sampleStarts[activeMinute] ?? [] {
            activeSamples.insert(sample)
        }

        // Determine whether the current minute is asleep, and if so add it to the total
        // FIXME: activeSamples is by definition not empty here
        if activeSamples.count > 0 {
            let sleepResolutionForActiveMinute = sleepResolution(minute: activeMinute, samples: activeSamples)
            if sleepResolutionForActiveMinute == SleepResolution.asleep || (
                sleepResolutionForActiveMinute == SleepResolution.ambiguous && wouldFirstMinuteBeAsleep(samples: activeSamples)) {
                totalSleepMinutes += 1
            }
        }

        for sample in sampleEnds[activeMinute] ?? [] {
            activeSamples.remove(sample)
        }

        lastMinuteProcessed = activeMinute
    }

    return totalSleepMinutes
}
