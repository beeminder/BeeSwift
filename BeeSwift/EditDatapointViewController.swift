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

    private let margin = 10
    
    var datapoint : ExistingDataPoint
    var goalSlug : String
    fileprivate var datePicker = UIDatePicker()
    fileprivate var scrollView = UIScrollView()
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
        
        self.scrollView.addSubview(self.datePicker)
        self.datePicker.snp.makeConstraints { (make) in
            make.top.equalTo(self.scrollView).offset(margin)
            make.centerX.equalTo(self.scrollView)
        }
        self.datePicker.datePickerMode = .date
        self.datePicker.preferredDatePickerStyle = .inline

        let daystamp = self.datapoint.daystamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        self.datePicker.date = dateFormatter.date(from: daystamp)!

        self.scrollView.addSubview(self.valueField)
        self.valueField.snp.makeConstraints { (make) in
            make.left.right.equalTo(self.datePicker)
            make.top.equalTo(self.datePicker.snp.bottom).offset(10)
        }
        self.valueField.delegate = self
        self.valueField.placeholder = "Value"
        self.valueField.textAlignment = .center
        self.valueField.keyboardType = .decimalPad
        self.valueField.text = "\(self.datapoint.value)"
        
        let accessory = DatapointValueAccessory()
        accessory.valueField = self.valueField
        self.valueField.inputAccessoryView = accessory
        
        self.scrollView.addSubview(self.commentField)
        self.commentField.snp.makeConstraints { (make) in
            make.left.right.equalTo(self.datePicker)
            make.top.equalTo(self.valueField.snp.bottom).offset(10)
        }
        self.commentField.placeholder = "Comment"
        self.commentField.textAlignment = .center
        self.commentField.text = self.datapoint.comment
        
        let updateButton = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            updateButton.configuration = .filled()
        }
        self.scrollView.addSubview(updateButton)
        updateButton.snp.makeConstraints { (make) in
            make.left.right.equalTo(self.datePicker)
            make.top.equalTo(self.commentField.snp.bottom).offset(10)
        }
        updateButton.setTitle("Update", for: .normal)
        updateButton.addTarget(self, action: #selector(self.updateButtonPressed), for: .touchUpInside)

        let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(self.deleteButtonPressed))
        deleteButton.tintColor = .red
        self.navigationItem.rightBarButtonItem = deleteButton

    }
    
    func urtext() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy MM dd"
        return "\(dateFormatter.string(from: self.datePicker.date)) \(self.valueField.text!) \"\(self.commentField.text!)\""
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

    
    @objc func updateButtonPressed() {
        Task { @MainActor in
            self.view.endEditing(true)
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud.mode = .indeterminate

            do {
                let params = [
                    "urtext": self.urtext()
                ]
                let _ = try await ServiceLocator.requestManager.put(url: "api/v1/users/\(ServiceLocator.currentUserManager.username!)/goals/\(self.goalSlug)/datapoints/\(self.datapoint.id).json", parameters: params)
                let hud = MBProgressHUD.forView(self.view)
                hud?.mode = .customView
                hud?.customView = UIImageView(image: UIImage(named: "checkmark"))
                hud?.hide(animated: true, afterDelay: 2)
            } catch {
                logger.error("Error updating datapoint for goal \(self.goalSlug): \(error)")
                let _ = MBProgressHUD.hide(for: self.view, animated: true)
            }
        }
    }
    
    func deleteDatapoint() {
        Task { @MainActor in
            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud.mode = .indeterminate

            do {
                let _ = try await ServiceLocator.requestManager.delete(url: "api/v1/users/\(ServiceLocator.currentUserManager.username!)/goals/\(self.goalSlug)/datapoints/\(self.datapoint.id).json", parameters: nil)

                let hud = MBProgressHUD.forView(self.view)
                hud?.mode = .customView
                hud?.customView = UIImageView(image: UIImage(named: "checkmark"))
                hud?.hide(animated: true, afterDelay: 2)
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
