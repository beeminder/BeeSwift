// Part of BeeSwift. Copyright Beeminder

import AppIntents
import BeeKit
import Foundation

typealias ServerError = BeeKit.ServerError

enum AddDataError: Error, CustomLocalizedStringResourceConvertible {
  case noGoal
  case noValue
  case apiError(String)
  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .noGoal: return "No goal specified. Please provide a goal slug."
    case .noValue: return "No value specified. Please provide a value for the datapoint."
    case .apiError(let message): return "Failed to add datapoint: \(message)"
    }
  }
}
