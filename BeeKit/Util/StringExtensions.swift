// Part of BeeSwift. Copyright Beeminder

import Foundation

public extension NumberFormatter {
  static let beeminderInputFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.groupingSeparator = ""
    formatter.numberStyle = .decimal
    return formatter
  }()

  static let beeminderDisplayFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 5
    return formatter
  }()
}

extension StringProtocol {
  /// capitalize only the first character of a string
  var capitalizingFirstCharacter: String {
    guard let first = self.first else { return "" }
    return String(first).uppercased() + self.dropFirst()
  }
}
