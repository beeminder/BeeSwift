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
    fileprivate var valueField = UITextField()
    fileprivate var commentField = UITextField()

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

        let formView = UIView()
        self.view.addSubview(formView)
        formView.snp.makeConstraints{ (make) in
            make.top.left.right.equalTo(self.view.safeAreaLayoutGuide).inset(10)
        }
        formView.layer.cornerRadius = 10
        formView.backgroundColor = UIColor(white: 0.5, alpha: 0.2)


        let dateLabel = UILabel()
        formView.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { (make) in
            make.top.left.right.equalTo(formView).inset(10)
        }
        dateLabel.text = "Date"
        dateLabel.layer.opacity = 0.5
        dateLabel.font = UIFont.systemFont(ofSize: 12)

        formView.addSubview(self.datePicker)
        self.datePicker.snp.makeConstraints { (make) in
            make.left.right.equalTo(formView)
            make.top.equalTo(dateLabel.snp.bottom)
        }
        self.datePicker.datePickerMode = .date
        self.datePicker.preferredDatePickerStyle = .compact
        self.datePicker.contentHorizontalAlignment = .left
        self.datePicker.backgroundColor = nil
        if let bgView = self.datePicker.subviews.first?.subviews.first?.subviews.first {
            bgView.backgroundColor = nil
        }

        let daystamp = self.datapoint.daystamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        self.datePicker.date = dateFormatter.date(from: daystamp)!

        // Add a horizontal line divider
        let divider1 = UIView()
        formView.addSubview(divider1)
        divider1.snp.makeConstraints { (make) in
            make.left.right.equalTo(formView).inset(10)
            make.top.equalTo(self.datePicker.snp.bottom)
            make.height.equalTo(1)
        }
        divider1.backgroundColor = UIColor(white: 0.5, alpha: 0.5)

        let valueLabel = UILabel()
        formView.addSubview(valueLabel)
        valueLabel.snp.makeConstraints { (make) in
            make.left.right.equalTo(formView).inset(10)
            make.top.equalTo(divider1.snp.bottom).offset(10)
        }
        valueLabel.text = "Value"
        valueLabel.layer.opacity = 0.5
        valueLabel.font = UIFont.systemFont(ofSize: 12)

        formView.addSubview(self.valueField)
        self.valueField.snp.makeConstraints { (make) in
            make.left.right.equalTo(formView).inset(10)
            make.top.equalTo(valueLabel.snp.bottom).offset(3)
        }
        self.valueField.delegate = self
        self.valueField.keyboardType = .decimalPad
        self.valueField.returnKeyType = .done
        self.valueField.text = "\(self.datapoint.value)"
        
        let accessory = DatapointValueAccessory()
        accessory.valueField = self.valueField
        self.valueField.inputAccessoryView = accessory

        // Add a horizontal line divider
        let divider = UIView()
        formView.addSubview(divider)
        divider.snp.makeConstraints { (make) in
            make.left.right.equalTo(formView).inset(10)
            make.top.equalTo(self.valueField.snp.bottom).offset(10)
            make.height.equalTo(1)
        }
        divider.backgroundColor = UIColor(white: 0.5, alpha: 0.5)

        let commentLabel = UILabel()
        formView.addSubview(commentLabel)
        commentLabel.snp.makeConstraints { (make) in
            make.left.right.equalTo(formView).inset(10)
            make.top.equalTo(divider).offset(10)
        }
        commentLabel.text = "Comment"
        commentLabel.layer.opacity = 0.5
        commentLabel.font = UIFont.systemFont(ofSize: 12)

        formView.addSubview(self.commentField)
        self.commentField.snp.makeConstraints { (make) in
            make.left.right.bottom.equalTo(formView).inset(10)
            make.top.equalTo(commentLabel.snp.bottom).offset(3)
        }
        self.commentField.text = self.datapoint.comment
        self.commentField.delegate = self
        self.commentField.returnKeyType = .done
        
        let updateButton = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            updateButton.configuration = .filled()
        }
        self.view.addSubview(updateButton)
        updateButton.snp.makeConstraints { (make) in
            make.left.right.equalTo(formView)
            make.top.equalTo(formView.snp.bottom).offset(20)
        }
        updateButton.setTitle("Update", for: .normal)
        updateButton.addTarget(self, action: #selector(self.updateButtonPressed), for: .touchUpInside)

        let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(self.deleteButtonPressed))
        deleteButton.tintColor = .red
        self.navigationItem.rightBarButtonItem = deleteButton
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let bgView = self.datePicker.subviews.first?.subviews.first?.subviews.first {
            bgView.backgroundColor = nil
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let bgView = self.datePicker.subviews.first?.subviews.first?.subviews.first {
            bgView.backgroundColor = nil
        }
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


    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if let bgView = self.datePicker.subviews.first?.subviews.first?.subviews.first {
            bgView.backgroundColor = nil
        }
    }

}
