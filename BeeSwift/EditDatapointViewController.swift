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
import OSLog

class EditDatapointViewController: UIViewController, UITextFieldDelegate {
    private let logger = Logger(subsystem: "com.beeminder.beeminder", category: "EditDatapointViewController")
    
    var datapoint : ExistingDataPoint
    var goalSlug : String
    fileprivate var datePicker = UIDatePicker()
    fileprivate var scrollView = UIScrollView()
    fileprivate var dateLabel = BSLabel()
    fileprivate var valueField = BSTextField()
    fileprivate var commentField = BSTextField()

    init(goalSlug: String, datapoint: ExistingDataPoint) {
        self.goalSlug = goalSlug
        self.datapoint = datapoint
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Edit Datapoint"

        self.view.backgroundColor = .systemBackground
        
        self.view.addSubview(self.scrollView)
        self.scrollView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin)
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
        self.valueField.text = "\(self.datapoint.value)"
        self.valueField.addTarget(self, action: #selector(self.textFieldEditingDidBegin), for: .editingDidBegin)
        
        let accessory = DatapointValueAccessory()
        accessory.valueField = self.valueField
        self.valueField.inputAccessoryView = accessory
        
        self.scrollView.addSubview(self.commentField)
        self.commentField.snp.makeConstraints { (make) in
            make.left.right.height.equalTo(self.dateLabel)
            make.top.equalTo(self.valueField.snp.bottom).offset(10)
        }
        self.commentField.placeholder = "Comment"
        self.commentField.textAlignment = .center
        self.commentField.text = self.datapoint.comment
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
        
        let daystamp = self.datapoint.daystamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        self.datePicker.date = dateFormatter.date(from: daystamp)!
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
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (textField.isEqual(self.valueField)) {
            // Only allow a single decimal separator (, or .)
            if textField.text!.components(separatedBy: ".").count > 1 {
                if string == "." || string == "," { return false }
            }
            if (string == ",") {
                textField.text = textField.text! + "."
                return false
            }
            // Only allow a single : time separator
            if textField.text!.components(separatedBy: ":").count > 1 && string == ":" {
                return false
            }
            if (string as NSString).rangeOfCharacter(from: CharacterSet(charactersIn: "1234567890.:").inverted).location != NSNotFound {
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
        Task { @MainActor in
            self.view.endEditing(true)
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud?.mode = .indeterminate

            do {
                let params = [
                    "access_token": CurrentUserManager.sharedManager.accessToken!,
                    "urtext": self.urtext()
                ]
                let _ = try await RequestManager.put(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goalSlug)/datapoints/\(self.datapoint.id).json", parameters: params)
                let hud = MBProgressHUD.allHUDs(for: self.view).first as? MBProgressHUD
                hud?.mode = .customView
                hud?.customView = UIImageView(image: UIImage(named: "checkmark"))
                hud?.hide(true, afterDelay: 2)
            } catch {
                logger.error("Error updating datapoint for goal \(self.goalSlug): \(error)")
                let _ = MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            }
        }
    }
    
    func deleteDatapoint() {
        Task { @MainActor in
            let params = [
                "access_token": CurrentUserManager.sharedManager.accessToken!
            ]
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud?.mode = .indeterminate

            do {
                let _ = try await RequestManager.delete(url: "api/v1/users/\(CurrentUserManager.sharedManager.username!)/goals/\(self.goalSlug)/datapoints/\(self.datapoint.id).json", parameters: params)

                let hud = MBProgressHUD.allHUDs(for: self.view).first as? MBProgressHUD
                hud?.mode = .customView
                hud?.customView = UIImageView(image: UIImage(named: "checkmark"))
                hud?.hide(true, afterDelay: 2)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.navigationController?.popViewController(animated: true)
                }
            } catch {
                logger.error("Error deleting datapoint for goal \(self.goalSlug): \(error)")

            }
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
