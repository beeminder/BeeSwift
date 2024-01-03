//
//  InlineDatePicker.swift
//  BeeSwift
//
//  A date picker component designed to be shown fully inline. Unlike
//  the default inline date picked mode it does not add margin or background.
//
//  This component modifies private subviews within the UIDatePicker hierarchy, so any
//  changes should be tested against all supported iOS versions

import Foundation

class InlineDatePicker : UIDatePicker {
    init() {
        super.init(frame: .zero)
        self.preferredDatePickerStyle = .compact

        resetStyle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        resetStyle()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        resetStyle()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        resetStyle()
    }

    private func resetStyle() {
        if let iosCompactView = self.subviews.first,
           let compactDateLabel = iosCompactView.subviews.first {

            // Switch to a transparent background
            if let bgView = compactDateLabel.subviews.first {
                bgView.backgroundColor = nil
            }

            // Remove the padding around the date label
            if compactDateLabel.subviews.count >= 2 {
                let linkedLabel = compactDateLabel.subviews[1]

                for constraint in compactDateLabel.constraints {
                    if constraint.firstItem === linkedLabel || constraint.secondItem === linkedLabel {
                        constraint.constant = 0
                    }
                }
            }
        }
    }

}
