//
//  DatapointValueAccessory.swift
//  BeeSwift
//
//  Created by Theo Spears on 11/19/22.
//  Copyright © 2022 APB. All rights reserved.
//

import Foundation
import UIKit

class DatapointValueAccessory : UIInputView {
    var valueField : UITextField?
    var colonButton: UIButton?

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 44), inputViewStyle: .keyboard)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        let colonButton = UIButton()
        self.colonButton = colonButton
        self.addSubview(colonButton)
        self.clipsToBounds = true

        colonButton.snp.makeConstraints { (make) -> Void in
            make.width.equalTo(self).multipliedBy(1.0/3.0).offset(-8)
            make.bottom.equalTo(-1)
            make.left.equalTo(7)
            make.top.equalTo(4)
        }
        colonButton.setTitle(":", for: UIControl.State())
        colonButton.addTarget(self, action: #selector(self.colonButtonPressed), for: .touchUpInside)

        // Style component to look similar to other keyboard buttons
        colonButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 26)
        colonButton.layer.cornerRadius = 5
        colonButton.layer.shadowColor = UIColor.black.cgColor
        colonButton.layer.shadowOffset = CGSize(width: 0, height: 0.5)
        colonButton.layer.shadowRadius = 0
        colonButton.layer.shadowOpacity = 0.5

        updateColorsToMatchMode()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColorsToMatchMode()
    }

    private func updateColorsToMatchMode() {
        guard let colonButton = self.colonButton else { return }

        if traitCollection.userInterfaceStyle == .dark {
            // Chosen to match keyboard button color in dark mode
            colonButton.backgroundColor = UIColor(white: 0.42, alpha: 1.0)
            colonButton.setTitleColor(.white, for: .normal)
        } else {
            colonButton.backgroundColor = .white
            colonButton.setTitleColor(.black, for: .normal)
        }
    }


    @objc func colonButtonPressed() {
        guard let valueField = self.valueField else { return }
        valueField.text = "\(valueField.text!):"
    }

}
