import Foundation

extension Goal {
  public var humanizedAutodata: String? {
    guard let autodata, !autodata.isEmpty else { return nil }
    switch autodata {
    case "ifttt": return "IFTTT"
    case "api": return "API"
    case "apple":
      let metric = HealthKitConfig.metrics.first(where: { $0.databaseString == self.healthKitMetric })
      return self.healthKitMetric == nil ? "Apple" : metric?.humanText
    default: return autodata.capitalized
    }
  }

  public var isDataProvidedAutomatically: Bool { return !(self.autodata ?? "").isEmpty }

  /// The daystamp corresponding to the day of the goal's creation, thus the first day we should add data points for.
  var initDaystamp: Daystamp {
    let initDate = Date(timeIntervalSince1970: Double(self.initDay))

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd"

    // initDate is constructed such that if we resolve it to a datetime in US Eastern Time, the date part
    // of that is guaranteed to be the user's local date on the day the goal was created.
    formatter.timeZone = TimeZone(identifier: "America/New_York")
    let dateString = formatter.string(from: initDate)

    return try! Daystamp(fromString: dateString)
  }

  public var cacheBustingThumbUrl: String {
    let thumbUrlStr = self.thumbUrl
    return cacheBuster(thumbUrlStr)
  }

  public var cacheBustingGraphUrl: String {
    let graphUrlStr = self.graphUrl
    return cacheBuster(graphUrlStr)
  }

  private func cacheBuster(_ originUrlStr: String) -> String {
    let queryCharacter = originUrlStr.range(of: "&") == nil ? "?" : "&"

    let cacheBustingUrlStr = "\(originUrlStr)\(queryCharacter)proctime=\(self.lastTouch)"

    return cacheBustingUrlStr
  }

  public func capitalSafesum() -> String { return self.safeSum.capitalizingFirstCharacter }

  public var hideDataEntry: Bool { return self.isDataProvidedAutomatically || self.won }

  public var isLinkedToHealthKit: Bool { return self.autodata == "apple" }

  /// A hint for the value the user is likely to enter, based on past data points
  public var suggestedNextValue: NSNumber? {
    let candidateDatapoints = self.recentData.filter { !$0.isDummy }.sorted(using: [
      SortDescriptor(\.updatedAt, order: .reverse)
    ])
    return candidateDatapoints.first?.value
  }
}
