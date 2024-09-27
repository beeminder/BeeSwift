//
//  ChooseHKMetricViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 3/29/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit
import HealthKit
import OSLog

import BeeKit

class ChooseHKMetricViewController: UIViewController {
    fileprivate let logger = Logger(subsystem: "com.beeminder.beeminder", category: "ChooseHKMetricViewController")
    fileprivate let cellReuseIdentifier = "hkMetricTableViewCell"
    fileprivate let headerReusedIdentifier = "hkMetricTableHeader"
    fileprivate var tableView = UITableView()
    let goal: Goal
    
    init(goal: Goal) {
        self.goal = goal
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .systemBackground
        self.title = "Choose HK Metric"
        
        let instructionsLabel = BSLabel()
        self.view.addSubview(instructionsLabel)
        
        instructionsLabel.attributedText = {
            let attrString = NSMutableAttributedString()
            
            attrString.append(NSMutableAttributedString(string: "Configuring goal ",
                                                        attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultFont]))
            
            attrString.append(NSMutableAttributedString(string: "\(self.goal.slug)\n",
                attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultBoldFont]))
            
            attrString.append(NSMutableAttributedString(string: "Apple Health metric as autodata!\nWith this metric as the autodata source for your goal, Apple Health will keep Beeminder up to date with your latest data automatically.\n(Technically it updates the Beeminder iOS app which updates Beeminder so you'll have to open the app occasionally.)\nPick a metric from the list below, then hit save to update your goal.",
                                                        attributes: [NSAttributedString.Key.font: UIFont.beeminder.defaultFontLight.withSize(Constants.defaultFontSize)]))
            return attrString
        }()
        
        instructionsLabel.snp.makeConstraints { (make) in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin).offset(20)
            make.centerX.equalTo(self.view)
            make.width.equalTo(self.view).multipliedBy(0.85)
        }
        instructionsLabel.numberOfLines = 0
        instructionsLabel.textAlignment = .center

        self.view.addSubview(self.tableView)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.snp.makeConstraints { (make) in
            make.top.equalTo(instructionsLabel.snp.bottom).offset(20)
            make.centerX.equalTo(self.view)
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin).offset(-20)
        }
        self.tableView.tableFooterView = UIView()
        self.tableView.register(HealthKitMetricTableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        // Re-enable the table on returning to the view
        self.tableView.isUserInteractionEnabled = true
    }
}

extension ChooseHKMetricViewController : UITableViewDelegate, UITableViewDataSource {
    var sortedHKMetrics: [HealthKitMetric] {
        HealthKitConfig.shared.metrics.sorted { (lhs, rhs) -> Bool in
            lhs.humanText < rhs.humanText
        }
    }

    var sortedMetricsByCategory: Dictionary<HealthKitCategory, [HealthKitMetric]> {
        var result = Dictionary<HealthKitCategory, [HealthKitMetric]>()
        for category in HealthKitCategory.allCases {
            result[category] = sortedHKMetrics.filter { $0.category == category }
        }
        return result
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return HealthKitCategory.allCases.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return HealthKitCategory.allCases[section].rawValue
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let category = HealthKitCategory.allCases[section]
        return self.sortedMetricsByCategory[category]!.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = HealthKitCategory.allCases[indexPath.section]
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier) as! HealthKitMetricTableViewCell
        
        cell.metric = self.sortedMetricsByCategory[section]![indexPath.row].humanText
        if tableView.indexPathForSelectedRow == indexPath {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Prevent double taps
        self.tableView.isUserInteractionEnabled = false

        Task { @MainActor in
            let section = HealthKitCategory.allCases[indexPath.section]
            let metric = self.sortedMetricsByCategory[section]![indexPath.row]

            do {
                try await ServiceLocator.healthStoreManager.requestAuthorization(metric: metric)
            } catch {
                logger.error("Error requesting permission for metric: \(error)")
                self.tableView.isUserInteractionEnabled = true
                return
            }

            self.navigationController?.pushViewController(ConfigureHKMetricViewController(goal: self.goal, metric: metric), animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
    }
}
