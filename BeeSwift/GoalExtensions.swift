// Part of BeeSwift. Copyright Beeminder

import BeeKit

extension Goal { var countdownColor: UIColor { return UIColor.Beeminder.SafetyBuffer.color(for: self.colorkey) } }

extension Goal {
  var dueByTableAttributedString: NSAttributedString {
    let textAndColor: [(text: String, color: UIColor)] = dueBy.sorted(using: SortDescriptor(\.key)).compactMap {
      $0.value.formattedDelta
    }.map { $0 == "✔" ? "✓" : $0 }.enumerated().map { offset, element in
      var color: UIColor {
        switch offset {
        case 0: return UIColor.Beeminder.SafetyBuffer.orange
        case 1: return UIColor.Beeminder.SafetyBuffer.blue
        case 2: return UIColor.Beeminder.SafetyBuffer.green
        default: return .label.withAlphaComponent(0.8)
        }
      }
      return (text: element, color: color)
    }
    let attrStr = NSMutableAttributedString()
    textAndColor.map { (text: String, color: UIColor) in
      NSAttributedString(string: text + " ", attributes: [.foregroundColor: color])
    }.forEach { attrStr.append($0) }
    return attrStr
  }
}
