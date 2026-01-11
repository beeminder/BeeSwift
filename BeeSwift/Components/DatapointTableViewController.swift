//
//  DatapointTableViewController.swift
//  BeeSwift
//
//  Created by Theo Spears on 11/27/22.
//  Copyright 2022 APB. All rights reserved.
//

import BeeKit
import Foundation
import UIKit

struct DatapointColumnWidths {
  let dayWidth: CGFloat
  let valueWidth: CGFloat
  static let columnSpacing: CGFloat = 8
  /// If max width exceeds 75th percentile by more than this factor, use percentile and allow overflow
  static let overflowThreshold: CGFloat = 1.5
}

protocol DatapointTableViewControllerDelegate: AnyObject {
  func datapointTableViewController(
    _ datapointTableViewController: DatapointTableViewController,
    didSelectDatapoint datapoint: BeeDataPoint
  )
}

class DatapointTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
  fileprivate var cellIdentifier = "datapointCell"
  fileprivate var datapointsTableView = DatapointsTableView()

  public weak var delegate: DatapointTableViewControllerDelegate?

  private var columnWidths: DatapointColumnWidths?

  public var datapoints: [BeeDataPoint] = [] { didSet { reloadTableData() } }

  public var hhmmformat: Bool = false { didSet { reloadTableData() } }

  private func reloadTableData() {
    columnWidths = calculateColumnWidths(for: datapoints)
    datapointsTableView.reloadData()
    // The number of rows or column widths may have changed, so trigger a re-layout
    datapointsTableView.invalidateIntrinsicContentSize()
  }

  override func viewDidLoad() {
    self.view.addSubview(self.datapointsTableView)

    self.datapointsTableView.dataSource = self
    self.datapointsTableView.delegate = self
    self.datapointsTableView.separatorStyle = .none
    self.datapointsTableView.isScrollEnabled = false
    self.datapointsTableView.rowHeight = 24
    self.datapointsTableView.register(DatapointTableViewCell.self, forCellReuseIdentifier: self.cellIdentifier)

    self.datapointsTableView.snp.makeConstraints { (make) -> Void in make.edges.equalToSuperview() }
  }

  func numberOfSections(in tableView: UITableView) -> Int { return 1 }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return datapoints.count }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: self.cellIdentifier) as! DatapointTableViewCell

    guard indexPath.row < datapoints.count else { return cell }
    let datapoint = datapoints[indexPath.row]

    let widths = columnWidths ?? DatapointColumnWidths(dayWidth: 20, valueWidth: 40)
    cell.configure(datapoint: datapoint, hhmmformat: hhmmformat, columnWidths: widths)

    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.view.endEditing(true)

    guard indexPath.row < datapoints.count else { return }
    let datapoint = datapoints[indexPath.row]

    self.delegate?.datapointTableViewController(self, didSelectDatapoint: datapoint)
  }

  private func calculateColumnWidths(for datapoints: [BeeDataPoint]) -> DatapointColumnWidths {
    let font = UIFont.beeminder.defaultFontPlain.withSize(Constants.defaultFontSize)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]

    let minWidth = ("0" as NSString).size(withAttributes: attributes).width

    // Measure actual day and value strings from data
    var dayWidths: [CGFloat] = []
    var valueWidths: [CGFloat] = []
    for datapoint in datapoints {
      let dayText = DatapointTableViewCell.formatDay(datapoint: datapoint)
      dayWidths.append((dayText as NSString).size(withAttributes: attributes).width)

      let valueText = DatapointTableViewCell.formatValue(datapoint: datapoint, hhmmformat: hhmmformat)
      valueWidths.append((valueText as NSString).size(withAttributes: attributes).width)
    }

    // Day column: always use max width (no overflow, dates should align)
    let dayWidth = dayWidths.max() ?? minWidth

    // Value column: use 75th percentile, but expand to max if:
    // - max isn't much wider than 75th percentile
    // - or max isn't that wide overall (under 60pt)
    let valueWidth = calculatePercentileWidth(widths: valueWidths, fallback: minWidth)

    return DatapointColumnWidths(dayWidth: ceil(dayWidth), valueWidth: ceil(valueWidth))
  }

  private func calculatePercentileWidth(widths: [CGFloat], fallback: CGFloat) -> CGFloat {
    guard !widths.isEmpty else { return fallback }

    let sorted = widths.sorted()
    let p75Index = min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.75)) - 1)
    let p75Width = sorted[max(0, p75Index)]
    let maxWidth = sorted.last!

    if maxWidth <= 60 || maxWidth <= p75Width * DatapointColumnWidths.overflowThreshold {
      return maxWidth
    } else {
      return p75Width
    }
  }
}
