//
//  EditDatapointViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 8/8/18.
//  Copyright © 2018 APB. All rights reserved.
//

import UIKit
import SwiftyJSON

class EditDatapointViewController: UIViewController {
    
    var datapointJSON : JSON?
    var goalSlug : String?
    fileprivate var datapointDate : Date?
    {
        didSet {
            self.updateDateLabel()
            if datapointDate != nil { self.datePicker.date = datapointDate! }
        }
    }
    fileprivate var datePicker = UIDatePicker()
    fileprivate var scrollView = UIScrollView()
    fileprivate var dateLabel = BSLabel()
    fileprivate var valueField = BSTextField()
    fileprivate var commentField = BSTextField()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Edit Datapoint"
        
        self.view.backgroundColor = .white
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.topLayoutGuide.snp.bottom)
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.bottom.equalTo(0)
        }
        
        self.scrollView.addSubview(self.dateLabel)
        self.dateLabel.snp.makeConstraints { (make) in
            make.top.left.equalTo(self.scrollView).offset(10)
            make.right.equalTo(self.scrollView).offset(-10)
            make.width.equalTo(self.scrollView).offset(-20)
            make.height.equalTo(42)
        }
        self.dateLabel.textAlignment = .center
        self.dateLabel.isUserInteractionEnabled = true
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(self.dateLabelTapped))
        self.dateLabel.addGestureRecognizer(tapGR)
        
        self.scrollView.addSubview(self.datePicker)
        self.datePicker.snp.makeConstraints { (make) in
            make.left.right.equalTo(self.scrollView)
            make.width.equalTo(self.scrollView)
            make.height.equalTo(0)
            make.top.equalTo(self.dateLabel.snp.bottom)
        }
        self.datePicker.datePickerMode = .date
        self.datePicker.isHidden = false
        
        
        self.scrollView.addSubview(self.valueField)
        self.valueField.snp.makeConstraints { (make) in
            make.left.right.height.equalTo(self.dateLabel)
            make.top.equalTo(self.datePicker.snp.bottom).offset(10)
        }
        self.valueField.placeholder = "Value"
        self.valueField.textAlignment = .center
        self.valueField.keyboardType = .decimalPad
        self.valueField.text = "\(self.datapointJSON!["value"].number!)"
        
        self.scrollView.addSubview(self.commentField)
        self.commentField.snp.makeConstraints { (make) in
            make.left.right.height.equalTo(self.dateLabel)
            make.top.equalTo(self.valueField.snp.bottom).offset(10)
        }
        self.commentField.placeholder = "Comment"
        self.commentField.textAlignment = .center
        self.commentField.text = self.datapointJSON!["comment"].string
        
        let updateButton = BSButton()
        self.scrollView.addSubview(updateButton)
        updateButton.snp.makeConstraints { (make) in
            make.left.right.height.equalTo(self.dateLabel)
            make.top.equalTo(self.commentField.snp.bottom).offset(10)
        }
        updateButton.setTitle("Update", for: .normal)
        updateButton.addTarget(self, action: #selector(self.updateButtonPressed), for: .touchUpInside)
        
        let deleteButton = BSButton()
        self.scrollView.addSubview(deleteButton)
        deleteButton.snp.makeConstraints { (make) in
            make.left.right.height.equalTo(self.dateLabel)
            make.top.equalTo(updateButton.snp.bottom).offset(10)
        }
        deleteButton.setTitle("Delete", for: .normal)
        deleteButton.addTarget(self, action: #selector(self.deleteButtonPressed), for: .touchUpInside)
        
        let daystamp = self.datapointJSON!["daystamp"].string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        if daystamp != nil { self.datapointDate = dateFormatter.date(from: daystamp!) }
    }
    
    func urtext() -> String {
        return "2018 08 09 1 \"comment\""
    }
    
    func updateDateLabel() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateLabel.text = dateFormatter.string(from: self.datapointDate!)
    }
    
    @objc func dateLabelTapped() {
        self.datePicker.snp.remakeConstraints { (make) in
            make.left.right.equalTo(self.scrollView)
            make.width.equalTo(self.scrollView)
            make.height.equalTo(200)
            make.top.equalTo(self.dateLabel.snp.bottom)
        }
    }
    
    @objc func updateButtonPressed() {
        let params = [
            "access_token": CurrentUserManager.sharedManager.accessToken!,
            "urtext": self.urtext()
        ]
        RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goalSlug!)/datapoints/\(self.datapointJSON!["id"].string).json", parameters: params, success: { (response) in
            //
        }) { (error) in
            //
        }
    }
    
    @objc func deleteButtonPressed() {
        let params = [
            "access_token": CurrentUserManager.sharedManager.accessToken!
        ]
        RequestManager.delete(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goalSlug!)/datapoints/\(self.datapointJSON!["id"].string).json", parameters: params, success: { (response) in
            //
        }) { (error) in
            //
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}
