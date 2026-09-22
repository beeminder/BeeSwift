// Types representing an individual data point within a goal

import Foundation
import SwiftyJSON

public protocol BeeDataPoint {
  var requestid: String { get }
  var daystamp: Daystamp { get }
  var value: NSNumber { get }
  var comment: String { get }
}

extension BeeDataPoint {
  /// The value as shown in the app: plain number, or h:mm for goals that use hhmm format.
  public func formattedValue(hhmmFormat: Bool) -> String {
    guard hhmmFormat else { return value.stringValue }
    let hours = Int(value.doubleValue)
    let minutes = Int((value.doubleValue.truncatingRemainder(dividingBy: 1) * 60).rounded()) % 60
    return String(hours) + ":" + String(format: "%02d", minutes)
  }
}

/// A data point we have created locally (e.g. from user input, or HealthKit)
public struct NewDataPoint: BeeDataPoint {
  public let requestid: String
  public let daystamp: Daystamp
  public let value: NSNumber
  public let comment: String
}
