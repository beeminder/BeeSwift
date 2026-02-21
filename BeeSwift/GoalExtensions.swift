// Part of BeeSwift. Copyright Beeminder

import BeeKit

extension Goal {
  public var countdownColor: UIColor { return UIColor.Beeminder.SafetyBuffer.color(for: self.colorkey) }
}
