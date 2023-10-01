//  PullToRefreshHint.swift
//  BeeSwift
//
//  A static view that indicates to the user that it is possible
//  to pull to refresh. Provides no behavior - the parent view should
//  add pull to refresh support as normal.

import Foundation

class PullToRefreshView : UIView {
    private let extraMargin = 30
    private let label = BSLabel()


    @IBInspectable var message: String = "Pull down to refresh" {
        didSet {
            label.text = message
        }
    }

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        self.addSubview(label)
        label.text = message
        label.textColor = UIColor.beeminder.gray
        label.textAlignment = NSTextAlignment.center
        label.numberOfLines = 0
        label.snp.makeConstraints { (make) -> Void in
            make.width.equalTo(self).multipliedBy(0.6)
            make.centerX.equalTo(self)
            make.top.equalTo(self).offset(extraMargin)
        }

        let iconLabel = UILabel()
        iconLabel.text = "⇩"
        iconLabel.font = UIFont.systemFont(ofSize: 30, weight: .ultraLight)
        iconLabel.textColor = UIColor.beeminder.gray
        iconLabel.textAlignment = NSTextAlignment.center
        self.addSubview(iconLabel)
        iconLabel.snp.makeConstraints { (make) -> Void in
            make.width.equalTo(self)
            make.left.equalTo(self)
            make.top.equalTo(label.snp.bottom).offset(5)
            make.bottom.equalTo(self)
        }
    }

}
