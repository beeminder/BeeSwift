// Part of BeeSwift. Copyright Beeminder

extension StringProtocol {
  /// capitalize only the first character of a string
  var capitalizingFirstCharacter: String {
    guard let first = self.first else { return "" }
    return String(first).uppercased() + self.dropFirst()
  }
}
