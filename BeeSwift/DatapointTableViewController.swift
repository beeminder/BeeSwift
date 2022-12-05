//
//  DatapointTableViewController.swift
//  BeeSwift
//
//  Created by Theo Spears on 11/27/22.
//  Copyright © 2022 APB. All rights reserved.
//

import Foundation
import UIKit

protocol DatapointTableViewControllerDelegate {
    func datapointTableViewController(_ datapointTableViewController: DatapointTableViewController, didSelectDatapoint datapoint: DataPoint)
}

class DatapointTableViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    fileprivate var cellIdentifier = "datapointCell"
    fileprivate var datapointsTableView = DatapointsTableView()


    public var delegate : DatapointTableViewControllerDelegate?

    public var datapoints : [DataPoint] = [] {
        didSet {
            // Cause the table to re-render to pick up the change to rows
            self.datapointsTableView.reloadData()
            // The number of rows may have changed, so we must trigger a re-layout to allow the
            // table view more or less space
            self.datapointsTableView.invalidateIntrinsicContentSize()
        }
    }

    public var hhmmformat : Bool = false {
        didSet {
            self.datapointsTableView.reloadData()
        }
    }

    override func viewDidLoad() {
        self.view.addSubview(self.datapointsTableView)

        self.datapointsTableView.dataSource = self
        self.datapointsTableView.delegate = self
        self.datapointsTableView.separatorStyle = .none
        self.datapointsTableView.isScrollEnabled = false
        self.datapointsTableView.rowHeight = 24
        self.datapointsTableView.register(DatapointTableViewCell.self, forCellReuseIdentifier: self.cellIdentifier)

        self.datapointsTableView.snp.makeConstraints { (make) -> Void in
            make.edges.equalToSuperview()
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return datapoints.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellIdentifier) as! DatapointTableViewCell

        guard indexPath.row < datapoints.count else {
            return cell
        }
        let datapoint = datapoints[indexPath.row]

        cell.datapointText = displayText(datapoint: datapoint)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.view.endEditing(true)

        guard indexPath.row < datapoints.count else { return }
        let datapoint = datapoints[indexPath.row]

        self.delegate?.datapointTableViewController(self, didSelectDatapoint: datapoint)
    }

    func displayText(datapoint: DataPoint) -> String {
        let daystamp = Int(datapoint.daystamp) ?? 0
        let day = daystamp != 0 ? String(format: "%02d", daystamp % 100) : "??" // Day is two least significant digits of daystamp

        var formattedValue: String
        if hhmmformat {
            let value = datapoint.value.doubleValue
            let hours = Int(value)
            let minutes = Int(value.truncatingRemainder(dividingBy: 1) * 60)
            formattedValue = String(hours) + ":" + String(format: "%02d", minutes)
        } else {
            formattedValue = datapoint.value.stringValue
        }
        let comment = datapoint.comment

        return "\(day) \(formattedValue) \(comment)"
    }
}
