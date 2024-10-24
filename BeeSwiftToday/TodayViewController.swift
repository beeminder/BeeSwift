//
//  TodayViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 10/13/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation
import UIKit
import SnapKit
import NotificationCenter

import BeeKit

class TodayViewController: UIViewController {
    var goals: [Goal] = [] {
        didSet {
            self.extensionContext?.widgetLargestAvailableDisplayMode = self.goals.count > 1 ? .expanded : .compact
        }
    }
    var tableView = UITableView()
    
    fileprivate let rowHeight = Constants.thumbnailHeight + 40
    fileprivate let cellReuseIdentifier = "todayTableViewCell"
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateDataSource), name: UserDefaults.didChangeNotification, object: nil)
        
        self.updateDataSource()
        
        self.preferredContentSize = CGSize(width: 0, height: self.rowHeight)
        
        self.view.addSubview(self.tableView)
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.tableFooterView = UIView()
        self.tableView.backgroundColor = UIColor.clear
        self.tableView.snp.makeConstraints { (make) in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(0)
            make.bottom.equalTo(0)
        }
        self.tableView.register(TodayTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
    }
    
    @objc func updateDataSource() {
        self.goals = Array(ServiceLocator.currentUserManager.user(context: ServiceLocator.persistentContainer.viewContext)?.goals ?? [])
    }
}

extension TodayViewController : NCWidgetProviding {
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        if activeDisplayMode == .expanded {
            self.preferredContentSize = CGSize(width: 0, height: self.rowHeight * self.goals.count)
        }
        else if activeDisplayMode == .compact {
            self.preferredContentSize = CGSize(width: 0, height: self.rowHeight)
        }
    }
}

extension TodayViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let slug = self.goals[indexPath.row].slug
        self.extensionContext?.open(URL(string: "beeminder://?slug=\(slug)")!, completionHandler: nil)
    }
}

extension TodayViewController : UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.goals.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CGFloat(self.rowHeight)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier, for: indexPath) as! TodayTableViewCell
        
        cell.goal = self.goals[indexPath.row]

        return cell
    }
}
