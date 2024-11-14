// Types representing an individual data point within a goal

import Foundation
import SwiftyJSON

public protocol BeeDataPoint {
    var requestid: String { get }
    var daystamp: Daystamp { get }
    var value: Double { get }
    var comment: String { get }
}

/// A data point we have created locally (e.g. from user input, or HealthKit)
public struct NewDataPoint : BeeDataPoint {
    public let requestid: String
    public let daystamp: Daystamp
    public let value: Double
    public let comment: String
}
