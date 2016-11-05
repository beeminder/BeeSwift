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

class TodayViewControler: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var tableView = UITableView()
    var goalDictionaries : Array<NSDictionary> = []
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(TodayViewControler.updateDataSource), name: UserDefaults.didChangeNotification, object: nil)
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.separatorStyle = .none
        self.tableView.register(TodayTableViewCell.self, forCellReuseIdentifier: "todayCell")
        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.top.equalTo(0)
            make.width.equalTo(self.view)
            make.bottom.equalTo(0)
        }
        self.updateDataSource()
        self.preferredContentSize = CGSize(width: 0, height: CGFloat(Double(self.goalDictionaries.count)*(122.0/200.0)*0.4*Double(self.view.frame.size.width)))
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.goalDictionaries.count
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let slug = self.goalDictionaries[(indexPath as NSIndexPath).row]["slug"] as! String
        
        self.extensionContext?.open(URL(string: "beeminder://?slug=\(slug)")!, completionHandler: nil)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "todayCell") as! TodayTableViewCell
        cell.goalDictionary = self.goalDictionaries[(indexPath as NSIndexPath).row]
        return cell
    }
    
    func updateDataSource() {
        let defaults = UserDefaults(suiteName: "group.beeminder.beeminder")
        self.goalDictionaries = defaults?.object(forKey: "todayGoalDictionaries") as! Array<NSDictionary>
    }
}
