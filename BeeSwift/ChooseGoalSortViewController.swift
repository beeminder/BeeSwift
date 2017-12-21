
//
//  ChooseGoalSortViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 12/21/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit

class ChooseGoalSortViewController: UIViewController {
    fileprivate var cellReuseIdentifier = "chooseGoalSortTableCell"
    fileprivate var tableView = UITableView()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.tableView)
        self.tableView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            if #available(iOS 11.0, *) {
                make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin)
                make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin)
            } else {
                make.bottom.equalTo(self.bottomLayoutGuide.snp.top)
                make.top.equalTo(self.topLayoutGuide.snp.bottom)
            }
        }
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

extension ChooseGoalSortViewController : UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Constants.goalSortOptions.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as? SettingsTableViewCell else { return UITableViewCell() }
        
        cell.title = Constants.goalSortOptions[indexPath.section]
        let selectedGoalSort = UserDefaults.standard.value(forKey: Constants.selectedGoalSortKey) as? String
        cell.accessoryType = Constants.goalSortOptions[indexPath.section] == selectedGoalSort ? .checkmark : .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UserDefaults.standard.set(Constants.goalSortOptions[indexPath.section], forKey: Constants.selectedGoalSortKey)
        UserDefaults.standard.synchronize()
        self.navigationController?.popViewController(animated: true)
    }
}
