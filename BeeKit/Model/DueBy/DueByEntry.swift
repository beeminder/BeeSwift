// Part of BeeSwift. Copyright Beeminder

import Foundation
import SwiftyJSON

@objc(DueByEntry) public class DueByEntry: NSObject, Codable {
  public let total: Double
  public let delta: Double
  public let formattedTotal: String
  public let formattedDelta: String
  init(total: Double, delta: Double, formattedTotalForBeedroid: String, formattedDeltaForBeedroid: String) {
    self.total = total
    self.delta = delta
    self.formattedTotal = formattedTotalForBeedroid
    self.formattedDelta = formattedDeltaForBeedroid
  }
  private enum CodingKeys: String, CodingKey, CaseIterable {
    case total
    case delta
    case formattedTotal = "formatted_total_for_beedroid"
    case formattedDelta = "formatted_delta_for_beedroid"
  }
  public init?(json: JSON) {
    guard let dueByDictionary = json.dictionary,
      CodingKeys.allCases.allSatisfy({ dueByDictionary.keys.contains($0.rawValue) })
    else { return nil }
    self.delta = json[CodingKeys.delta.rawValue].doubleValue
    self.total = json[CodingKeys.total.rawValue].doubleValue
    self.formattedDelta = json[CodingKeys.formattedDelta.rawValue].stringValue
    self.formattedTotal = json[CodingKeys.formattedTotal.rawValue].stringValue
  }

}
