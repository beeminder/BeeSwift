//
//  DatapointValueAccessory.swift
//  BeeSwift
//
//  Created by Theo Spears on 11/19/22.
//  Copyright © 2022 APB. All rights reserved.
//

import Foundation
import UIKit

class DatapointValueAccessory : UIView {
    var valueField : UITextField?

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        self.backgroundColor = UIColor.white

        let colonButton = UIButton()
        self.addSubview(colonButton)
        self.clipsToBounds = true
        colonButton.snp.makeConstraints { (make) -> Void in
            make.width.equalTo(self).multipliedBy(1.0/3.0).offset(-1)
            make.height.equalTo(self)
            make.left.equalTo(-1)
            make.top.equalTo(0)
        }
        colonButton.setTitle(":", for: UIControl.State())
        colonButton.layer.borderWidth = 1
        colonButton.layer.borderColor = UIColor.beeminder.gray.cgColor
        colonButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 26)
        colonButton.setTitleColor(UIColor.black, for: UIControl.State())
        colonButton.addTarget(self, action: #selector(self.colonButtonPressed), for: .touchUpInside)
    }

    @objc func colonButtonPressed() {
        guard let valueField = self.valueField else { return }
        valueField.text = "\(valueField.text!):"
    }
}
