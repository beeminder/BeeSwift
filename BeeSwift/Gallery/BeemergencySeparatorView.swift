//
//  BeemergencySeparatorView.swift
//  BeeSwift
//
//  A thin dashed line separator between beemergency goals due tonight and those due tomorrow.
//

import UIKit

class BeemergencySeparatorView: UICollectionReusableView {
  static let elementKind = "beemergency-separator"

  private let dashedLineLayer = CAShapeLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupDashedLine()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupDashedLine()
  }

  private func setupDashedLine() {
    dashedLineLayer.strokeColor = UIColor.Beeminder.gray.cgColor
    dashedLineLayer.lineWidth = 1
    dashedLineLayer.lineDashPattern = [4, 4]
    dashedLineLayer.fillColor = nil
    layer.addSublayer(dashedLineLayer)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateDashedLinePath()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    dashedLineLayer.strokeColor = UIColor.Beeminder.gray.cgColor
  }

  private func updateDashedLinePath() {
    let path = UIBezierPath()
    let y = bounds.midY
    let horizontalInset: CGFloat = 20
    path.move(to: CGPoint(x: horizontalInset, y: y))
    path.addLine(to: CGPoint(x: bounds.width - horizontalInset, y: y))
    dashedLineLayer.path = path.cgPath
  }
}
