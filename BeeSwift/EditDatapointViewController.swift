//
//  EditDatapointViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 8/8/18.
//  Copyright © 2018 APB. All rights reserved.
//

import UIKit
import SwiftyJSON
import MBProgressHUD

class EditDatapointViewController: UIViewController, UITextFieldDelegate {
    
    var datapointJSON : JSON?
    var goalSlug : String?
    fileprivate var datePicker = UIDatePicker()
    fileprivate var scrollView = UIScrollView()
    fileprivate var dateLabel = BSLabel()
    fileprivate var valueField = BSTextField()
    fileprivate var commentField = BSTextField()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Edit Datapoint"
        
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        
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
        self.datePicker.isHidden = true
        self.datePicker.addTarget(self, action: #selector(self.datePickerValueChanged), for: .valueChanged)
        
        self.scrollView.addSubview(self.valueField)
        self.valueField.snp.makeConstraints { (make) in
            make.left.right.height.equalTo(self.dateLabel)
            make.top.equalTo(self.datePicker.snp.bottom).offset(10)
        }
        self.valueField.delegate = self
        self.valueField.placeholder = "Value"
        self.valueField.textAlignment = .center
        self.valueField.keyboardType = .decimalPad
        self.valueField.text = "\(self.datapointJSON!["value"].number!)"
        self.valueField.addTarget(self, action: #selector(self.textFieldEditingDidBegin), for: .editingDidBegin)
        
        let accessory = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        accessory.backgroundColor = UIColor.white
        self.valueField.inputAccessoryView = accessory
        let colonButton = UIButton()
        accessory.addSubview(colonButton)
        accessory.clipsToBounds = true
        colonButton.snp.makeConstraints { (make) -> Void in
            make.width.equalTo(accessory).multipliedBy(1.0/3.0).offset(-1)
            make.height.equalTo(accessory)
            make.left.equalTo(-1)
            make.top.equalTo(0)
        }
        colonButton.setTitle(":", for: UIControlState())
        colonButton.layer.borderWidth = 1
        colonButton.layer.borderColor = UIColor.beeGrayColor().cgColor
        colonButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 26)
        colonButton.setTitleColor(UIColor.black, for: UIControlState())
        colonButton.addTarget(self, action: #selector(self.colonButtonPressed), for: .touchUpInside)
        
        self.scrollView.addSubview(self.commentField)
        self.commentField.snp.makeConstraints { (make) in
            make.left.right.height.equalTo(self.dateLabel)
            make.top.equalTo(self.valueField.snp.bottom).offset(10)
        }
        self.commentField.placeholder = "Comment"
        self.commentField.textAlignment = .center
        self.commentField.text = self.datapointJSON!["comment"].string
        self.commentField.addTarget(self, action: #selector(self.textFieldEditingDidBegin), for: .editingDidBegin)
        
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
        if daystamp != nil { self.datePicker.date = dateFormatter.date(from: daystamp!)! }
        self.updateDateLabel()
    }
    
    func urtext() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy MM dd"
        return "\(dateFormatter.string(from: self.datePicker.date)) \(self.valueField.text!) \"\(self.commentField.text!)\""
    }
    
    func updateDateLabel() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateLabel.text = dateFormatter.string(from: self.datePicker.date)
    }
    
    @objc func datePickerValueChanged() {
        self.updateDateLabel()
    }
    
    @objc func textFieldEditingDidBegin() {
        self.datePicker.snp.updateConstraints { (make) in
            make.height.equalTo(0)
        }
        self.datePicker.isHidden = true
    }
    
    @objc func colonButtonPressed() {
        self.valueField.text = "\(self.valueField.text!):"
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (textField.isEqual(self.valueField)) {
            if textField.text!.components(separatedBy: ".").count > 1 {
                if string == "." || string == "," { return false }
            }
            if (string == ",") {
                textField.text = textField.text! + "."
                return false
            }
            if (string as NSString).rangeOfCharacter(from: CharacterSet(charactersIn: "1234567890.").inverted).location != NSNotFound {
                return false
            }
        }
        return true
    }
    
    @objc func dateLabelTapped() {
        self.datePicker.snp.updateConstraints { (make) in
            if self.datePicker.isHidden {
                make.height.equalTo(200)
            } else {
                make.height.equalTo(0)
            }
        }
        self.datePicker.isHidden = !self.datePicker.isHidden
        self.view.endEditing(true)
    }
    
    @objc func updateButtonPressed() {
        self.view.endEditing(true)
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud?.mode = .indeterminate
        let params = [
            "access_token": CurrentUserManager.sharedManager.accessToken!,
            "urtext": self.urtext()
        ]
        RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goalSlug!)/datapoints/\(self.datapointJSON!["id"]["$oid"].string!).json", parameters: params, success: { (response) in
            let hud = MBProgressHUD.allHUDs(for: self.view).first as? MBProgressHUD
            hud?.mode = .customView
            hud?.customView = UIImageView(image: UIImage(named: "checkmark"))
            hud?.hide(true, afterDelay: 2)
        }) { (error) in
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            // alert
        }
    }
    
    func deleteDatapoint() {
        let params = [
            "access_token": CurrentUserManager.sharedManager.accessToken!
        ]
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud?.mode = .indeterminate
        RequestManager.delete(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goalSlug!)/datapoints/\(self.datapointJSON!["id"]["$oid"].string!).json", parameters: params, success: { (response) in
            let hud = MBProgressHUD.allHUDs(for: self.view).first as? MBProgressHUD
            hud?.mode = .customView
            hud?.customView = UIImageView(image: UIImage(named: "checkmark"))
            hud?.hide(true, afterDelay: 2)
            if let goalVC = self.navigationController?.viewControllers[1] as? GoalViewController {
                goalVC.refreshGoal()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.navigationController?.popViewController(animated: true)
            }
        }) { (error) in
            //
        }
    }
    
    @objc func deleteButtonPressed() {
        self.view.endEditing(true)
        let alert = UIAlertController(title: "Confirm deletion", message: "Are you sure?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            self.deleteDatapoint()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            //
        }))
        
        self.present(alert, animated: true, completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}
