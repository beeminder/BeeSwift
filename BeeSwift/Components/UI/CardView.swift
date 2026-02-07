// Part of BeeSwift. Copyright Beeminder

import UIKit

class CardView: UIView {
  enum Style {
    case primary
    case secondary
    case tertiary
  }
  var style: Style = .primary { didSet { updateStyle() } }
  var cornerRadius: CGFloat = CardLookConstants.cornerRadius { didSet { layer.cornerRadius = cornerRadius } }
  var shadowOpacity: Float = CardLookConstants.shadowOpacity { didSet { layer.shadowOpacity = shadowOpacity } }
  var shadowRadius: CGFloat = CardLookConstants.shadowRadius { didSet { layer.shadowRadius = shadowRadius } }
  var shadowOffset: CGSize = CardLookConstants.shadowOffset { didSet { layer.shadowOffset = shadowOffset } }
  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
  }
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }
  private func setupView() {
    backgroundColor = CardLookConstants.primaryBackground
    layer.cornerRadius = cornerRadius
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = shadowOpacity
    layer.shadowRadius = shadowRadius
    layer.shadowOffset = shadowOffset
    layer.masksToBounds = false
  }
  private func updateStyle() {
    switch style {
    case .primary: backgroundColor = CardLookConstants.primaryBackground
    case .secondary: backgroundColor = CardLookConstants.secondaryBackground
    case .tertiary: backgroundColor = .clear
    }
  }
}
