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

class TodayViewController: UIViewController {
    
    var goalDictionaries : Array<NSDictionary> = []
    var tableView = UITableView()
    
    fileprivate let rowHeight = Constants.thumbnailHeight + 40
    fileprivate let cellReuseIdentifier = "todayTableViewCell"
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateDataSource), name: UserDefaults.didChangeNotification, object: nil)
        
        self.updateDataSource()
        
        self.preferredContentSize = CGSize.init(width: 0, height: self.rowHeight)
        
        if self.goalDictionaries.count > 1 {
            self.extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        }
        
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
        let defaults = UserDefaults(suiteName: "group.beeminder.beeminder")
        self.goalDictionaries = defaults?.object(forKey: "todayGoalDictionaries") as! Array<NSDictionary>
    }
}

extension TodayViewController : NCWidgetProviding {
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        if activeDisplayMode == .expanded {
            self.preferredContentSize = CGSize.init(width: 0, height: self.rowHeight * self.goalDictionaries.count)
        }
        else if activeDisplayMode == .compact {
            self.preferredContentSize = CGSize.init(width: 0, height: self.rowHeight)
        }
    }
}

extension TodayViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let slug = self.goalDictionaries[indexPath.row]["slug"] as? String else { return }
        self.extensionContext?.open(URL(string: "beeminder://?slug=\(slug)")!, completionHandler: nil)
    }
}

extension TodayViewController : UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.goalDictionaries.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CGFloat(self.rowHeight)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier, for: indexPath) as! TodayTableViewCell
        
        cell.goalDictionary = self.goalDictionaries[indexPath.row]
        
        return cell
    }
}
