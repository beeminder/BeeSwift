//
//  GalleryViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import UIKit
import MagicalRecord
import SnapKit
import MBProgressHUD
import SwiftyJSON
import HealthKit

class GalleryViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, UICollectionViewDataSource {
    
    var collectionView :UICollectionView?
    var collectionViewLayout :UICollectionViewLayout?
    let lastUpdatedView = UIView()
    let lastUpdatedLabel = BSLabel()
    let cellReuseIdentifier = "Cell"
    let newGoalCellReuseIdentifier = "NewGoalCell"
    var refreshControl = UIRefreshControl()
    var deadbeatView = UIView()
    let noGoalsLabel = BSLabel()
    var lastUpdated : Date?
    
    var jsonGoals : Array<JSONGoal> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleSignIn), name: NSNotification.Name(rawValue: CurrentUserManager.signedInNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleSignOut), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.openGoalFromNotification(_:)), name: NSNotification.Name(rawValue: "openGoal"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleCreateGoalButtonPressed), name: NSNotification.Name(rawValue: "createGoalButtonPressed"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didFetchData), name: Notification.Name(rawValue: "dataSyncManagerSuccess"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.didBecomeActive), name: Notification.Name(rawValue: "didBecomeActive"), object: nil)
        
        self.collectionViewLayout = UICollectionViewFlowLayout()
        self.collectionView = UICollectionView(frame: self.view.frame, collectionViewLayout: self.collectionViewLayout!)
        self.collectionView?.backgroundColor = UIColor.white
        self.collectionView?.alwaysBounceVertical = true
        self.collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "footer")
        self.view.backgroundColor = UIColor.white
        self.title = "Goals"
        
        let item = UIBarButtonItem(image: UIImage(named: "Settings"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(GalleryViewController.settingsButtonPressed))
        self.navigationItem.rightBarButtonItem = item
        
        self.view.addSubview(self.lastUpdatedView)
        self.lastUpdatedView.backgroundColor = UIColor.beeGrayColor()
        self.lastUpdatedView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.topLayoutGuide.snp.bottom)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.lastUpdatedView.addSubview(self.lastUpdatedLabel)
        self.lastUpdatedLabel.text = "Last updated:"
        self.lastUpdatedLabel.font = UIFont(name: "Avenir", size: Constants.defaultFontSize)
        self.lastUpdatedLabel.textAlignment = NSTextAlignment.center
        self.lastUpdatedLabel.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(3)
            make.bottom.equalTo(-3)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.updateLastUpdatedLabel()
        Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(GalleryViewController.updateLastUpdatedLabel), userInfo: nil, repeats: true)
        
        self.view.addSubview(self.deadbeatView)
        self.deadbeatView.backgroundColor = UIColor.beeGrayColor()
        self.deadbeatView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(self.lastUpdatedView.snp.bottom)
            if !CurrentUserManager.sharedManager.isDeadbeat() {
                make.height.equalTo(0)
            }
        }
        
        let deadbeatLabel = BSLabel()
        self.deadbeatView.addSubview(deadbeatLabel)
        deadbeatLabel.textColor = UIColor.red
        deadbeatLabel.numberOfLines = 0
        deadbeatLabel.font = UIFont(name: "Avenir-Heavy", size: 13)
        deadbeatLabel.text = "Hey! Beeminder couldn't charge your credit card, so you can't see your graphs. Please update your card on beeminder.com or email support@beeminder.com if this is a mistake."
        deadbeatLabel.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(3)
            make.bottom.equalTo(-3)
            make.left.equalTo(10)
            make.right.equalTo(-10)
        }
        
        self.collectionView!.delegate = self
        self.collectionView!.dataSource = self
        self.collectionView!.register(GoalCollectionViewCell.self, forCellWithReuseIdentifier: self.cellReuseIdentifier)
        self.collectionView!.register(NewGoalCollectionViewCell.self, forCellWithReuseIdentifier: self.newGoalCellReuseIdentifier)
        self.view.addSubview(self.collectionView!)
        
        self.refreshControl.addTarget(self, action: #selector(self.fetchData), for: UIControlEvents.valueChanged)
        self.collectionView!.addSubview(self.refreshControl)
        
        self.collectionView!.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.deadbeatView.snp.bottom)
            if #available(iOS 11.0, *) {
                make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin)
                make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin)
            } else {
                make.left.equalTo(0)
                make.right.equalTo(0)
            }
            make.bottom.equalTo(0)
        }
        
        self.view.addSubview(self.noGoalsLabel)
        self.noGoalsLabel.snp.makeConstraints { (make) in
            make.top.left.right.equalTo(self.collectionView!)
        }
        self.noGoalsLabel.text = "No goals yet!\n\nIn-app goal creation is coming soon, but for now, head to beeminder.com to create a goal."
        self.noGoalsLabel.textAlignment = .center
        self.noGoalsLabel.numberOfLines = 0
        self.noGoalsLabel.isHidden = true
        
        self.fetchData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !CurrentUserManager.sharedManager.signedIn() {
            self.present(SignInViewController(), animated: true, completion: nil)
        }
        self.fetchData()
    }
    
    @objc func settingsButtonPressed() {
        self.navigationController?.pushViewController(SettingsViewController(), animated: true)
    }
    
    @objc func userDefaultsDidChange() {
        self.sortGoals()
        self.collectionView?.reloadData()
    }
    
    @objc func handleSignIn() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func handleSignOut() {
        self.jsonGoals = []
        self.collectionView?.reloadData()
        self.present(SignInViewController(), animated: true, completion: nil)
    }
    
    func updateDeadbeatHeight() {
        self.deadbeatView.snp.remakeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(self.lastUpdatedView.snp.bottom)
            if !CurrentUserManager.sharedManager.isDeadbeat() {
                make.height.equalTo(0)
            }
        }
    }
    
    @objc func handleCreateGoalButtonPressed() {
        self.navigationController?.pushViewController(CreateGoalViewController(), animated: true)
    }
    
    @objc func updateLastUpdatedLabel() {
        if let lastUpdated = self.lastUpdated {
            if lastUpdated.timeIntervalSinceNow < -3600 {
                let lastText :NSMutableAttributedString = NSMutableAttributedString(string: "Last updated: more than an hour ago")
                lastText.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: lastText.string.count))
                self.lastUpdatedLabel.attributedText = lastText
            }
            else if lastUpdated.timeIntervalSinceNow < -120 {
                self.lastUpdatedLabel.text = "Last updated: \(-1*Int(lastUpdated.timeIntervalSinceNow/60)) minutes ago"
            }
            else if lastUpdated.timeIntervalSinceNow < -60 {
                self.lastUpdatedLabel.text = "Last updated: 1 minute ago"
            }
            else {
                self.lastUpdatedLabel.text = "Last updated: less than a minute ago"
            }
        }
        else {
            let lastText :NSMutableAttributedString = NSMutableAttributedString(string: "Last updated: a long time ago...")
            lastText.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor.red, range: NSRange(location: 0, length: lastText.string.count))
            self.lastUpdatedLabel.attributedText = lastText
        }
    }
    
    @objc func didBecomeActive() {
        self.refreshControl.endRefreshing()
    }
    
    @objc func didFetchData() {
        self.refreshControl.endRefreshing()
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
        let isRegisteredForNotifications = UIApplication.shared.currentUserNotificationSettings?.types.contains(UIUserNotificationType.alert) ?? false
        if !isRegisteredForNotifications {
            RemoteNotificationsManager.sharedManager.turnNotificationsOn()
        }
        self.collectionView!.reloadData()
        self.updateDeadbeatHeight()
        self.lastUpdated = Date()
        self.updateLastUpdatedLabel()
        if self.jsonGoals.count == 0 {
            self.noGoalsLabel.isHidden = false
            self.collectionView?.isHidden = true
        } else {
            self.noGoalsLabel.isHidden = true
            self.collectionView?.isHidden = false
        }
    }
    
    func setupHealthKit() {
        var permissions = Set<HKObjectType>.init()
        self.jsonGoals.forEach { (goal) in
            if goal.hkPermissionType() != nil { permissions.insert(goal.hkPermissionType()!) }
        }
        guard permissions.count > 0 else { return }
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        
        healthStore.requestAuthorization(toShare: nil, read: permissions, completion: { (success, error) in
            self.jsonGoals.forEach { (goal) in goal.setupHealthKit() }
        })
    }
    
    @objc func fetchData() {
        guard let username = CurrentUserManager.sharedManager.username else { return }
        if self.jsonGoals.count == 0 {
            MBProgressHUD.showAdded(to: self.view, animated: true)
        }
        RequestManager.get(url: "api/v1/users/\(username)/goals.json", parameters: nil, success: { (responseJSON) in
            guard let responseGoals = JSON(responseJSON!).array else { return }
            var jGoals : [JSONGoal] = []
            responseGoals.forEach({ (goalJSON) in
                let g = JSONGoal(json: goalJSON)
                jGoals.append(g)
            })
            self.jsonGoals = jGoals
            self.sortGoals()
            self.didFetchData()
            self.setupHealthKit()
        }) { (responseError) in
            print(responseError)
            if let errorString = responseError?.localizedDescription {
                let alert = UIAlertController(title: "Error fetching goals", message: errorString, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
            self.refreshControl.endRefreshing()
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            self.collectionView!.reloadData()
        }
    }
    
    func sortGoals() {
        self.jsonGoals.sort(by: { (goal1, goal2) -> Bool in
            if let selectedGoalSort = UserDefaults.standard.value(forKey: Constants.selectedGoalSortKey) as? String {
                if selectedGoalSort == Constants.nameGoalSortString {
                    return goal1.slug < goal2.slug
                }
                else if selectedGoalSort == Constants.recentDataGoalSortString {
                    return goal1.lasttouch!.intValue > goal2.lasttouch!.intValue
                }
                else if selectedGoalSort == Constants.pledgeGoalSortString {
                    return goal1.pledge.intValue > goal2.pledge.intValue
                }
            }
            return goal1.deadline.intValue < goal2.deadline.intValue
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.jsonGoals.count + 1
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 320, height: 120)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if (indexPath as NSIndexPath).row >= self.jsonGoals.count {
            let cell:NewGoalCollectionViewCell = self.collectionView!.dequeueReusableCell(withReuseIdentifier: self.newGoalCellReuseIdentifier, for: indexPath) as! NewGoalCollectionViewCell
            return cell
        }
        let cell:GoalCollectionViewCell = self.collectionView!.dequeueReusableCell(withReuseIdentifier: self.cellReuseIdentifier, for: indexPath) as! GoalCollectionViewCell
        
        let jsonGoal:JSONGoal = self.jsonGoals[(indexPath as NSIndexPath).row]
        
        cell.jsonGoal = jsonGoal
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: 320, height: section == 0 && self.jsonGoals.count > 0 ? 5 : 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let row = (indexPath as NSIndexPath).row
        if row < self.jsonGoals.count { self.openGoal(self.jsonGoals[row]) }
    }

    @objc func openGoalFromNotification(_ notification: Notification) {
        let slug = (notification as NSNotification).userInfo!["slug"] as! String
        let matchingGoal = self.jsonGoals.filter({ (jsonGoal) -> Bool in
            return jsonGoal.slug == slug
        }).last
        if matchingGoal != nil {
            self.navigationController?.popToRootViewController(animated: false)
            self.openGoal(matchingGoal!)
        }
    }
    
    func openGoal(_ goal: JSONGoal) {
        let goalViewController = GoalViewController()
        goalViewController.jsonGoal = goal
        self.navigationController?.pushViewController(goalViewController, animated: true)
    }
}

