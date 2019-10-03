//
//  GalleryViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import UIKit
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
    
    var goals : Array<JSONGoal> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleSignIn), name: NSNotification.Name(rawValue: CurrentUserManager.signedInNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleSignOut), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.openGoalFromNotification(_:)), name: NSNotification.Name(rawValue: "openGoal"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleCreateGoalButtonPressed), name: NSNotification.Name(rawValue: "createGoalButtonPressed"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleGoalsFetchedNotification), name: NSNotification.Name(rawValue: CurrentUserManager.goalsFetchedNotificationName), object: nil)
        
        self.collectionViewLayout = UICollectionViewFlowLayout()
        self.collectionView = UICollectionView(frame: self.view.frame, collectionViewLayout: self.collectionViewLayout!)
        if #available(iOS 13.0, *) {
            self.collectionView?.backgroundColor = .systemBackground
        } else {
            self.collectionView?.backgroundColor = UIColor.white
        }
        
        self.collectionView?.alwaysBounceVertical = true
        self.collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "footer")
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
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
        
        self.refreshControl.addTarget(self, action: #selector(self.fetchGoals), for: UIControlEvents.valueChanged)
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
        
        self.fetchGoals()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !CurrentUserManager.sharedManager.signedIn() {
            self.present(SignInViewController(), animated: true, completion: nil)
        }
        self.fetchGoals()
    }
    
    @objc func handleGoalsFetchedNotification() {
        self.goals = CurrentUserManager.sharedManager.goals
        self.lastUpdated = CurrentUserManager.sharedManager.goalsFetchedAt
        self.didFetchGoals()
    }
    
    @objc func settingsButtonPressed() {
        self.navigationController?.pushViewController(SettingsViewController(), animated: true)
    }
    
    @objc func userDefaultsDidChange() {
        self.sortGoals()
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }
    
    @objc func handleSignIn() {
        self.dismiss(animated: true, completion: nil)
        self.fetchGoals()
    }
    
    @objc func handleSignOut() {
        self.goals = []
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
        var lastTextString = ""
        var color = UIColor.black
        if let lastUpdated = self.lastUpdated {
            if lastUpdated.timeIntervalSinceNow < -3600 {
                color = UIColor.red
                lastTextString = "Last updated: a long time ago..."
            }
            else if lastUpdated.timeIntervalSinceNow < -120 {
                color = UIColor.black
                lastTextString = "Last updated: \(-1*Int(lastUpdated.timeIntervalSinceNow/60)) minutes ago"
            }
            else if lastUpdated.timeIntervalSinceNow < -60 {
                color = UIColor.black
                lastTextString = "Last updated: 1 minute ago"
            }
            else {
                color = UIColor.black
                lastTextString = "Last updated: less than a minute ago"
            }
        }
        else {
            color = UIColor.red
            lastTextString = "Last updated: a long time ago..."
        }
        let lastText :NSMutableAttributedString = NSMutableAttributedString(string: lastTextString)
        lastText.addAttribute(NSAttributedStringKey.foregroundColor, value: color, range: NSRange(location: 0, length: lastText.string.count))
        self.lastUpdatedLabel.attributedText = lastText
    }
    
    @objc func didFetchGoals() {
        self.sortGoals()
        self.setupHealthKit()
        self.refreshControl.endRefreshing()
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
        self.collectionView!.reloadData()
        self.updateDeadbeatHeight()
        self.lastUpdated = Date()
        self.updateLastUpdatedLabel()
        if self.goals.count == 0 {
            self.noGoalsLabel.isHidden = false
            self.collectionView?.isHidden = true
        } else {
            self.noGoalsLabel.isHidden = true
            self.collectionView?.isHidden = false
        }
    }
    
    func setupHealthKit() {
        var permissions = Set<HKObjectType>.init()
        self.goals.forEach { (goal) in
            if goal.hkPermissionType() != nil { permissions.insert(goal.hkPermissionType()!) }
        }
        guard permissions.count > 0 else { return }
        guard let healthStore = HealthStoreManager.sharedManager.healthStore else { return }
        
        healthStore.requestAuthorization(toShare: nil, read: permissions, completion: { (success, error) in
            self.goals.forEach { (goal) in goal.setupHealthKit() }
        })
    }
    
    @objc func fetchGoals() {
        if self.goals.count == 0 {
            MBProgressHUD.showAdded(to: self.view, animated: true)
        }
        CurrentUserManager.sharedManager.fetchGoals(success: { (goals) in
            self.goals = goals
            self.didFetchGoals()
        }) { (error) in
            if let errorString = error?.localizedDescription {
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
        self.goals.sort(by: { (goal1, goal2) -> Bool in
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
            return goal1.losedate.intValue < goal2.losedate.intValue
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.goals.count + 1
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 320, height: 120)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if (indexPath as NSIndexPath).row >= self.goals.count {
            let cell:NewGoalCollectionViewCell = self.collectionView!.dequeueReusableCell(withReuseIdentifier: self.newGoalCellReuseIdentifier, for: indexPath) as! NewGoalCollectionViewCell
            return cell
        }
        let cell:GoalCollectionViewCell = self.collectionView!.dequeueReusableCell(withReuseIdentifier: self.cellReuseIdentifier, for: indexPath) as! GoalCollectionViewCell
        
        let jsonGoal:JSONGoal = self.goals[(indexPath as NSIndexPath).row]
        
        cell.jsonGoal = jsonGoal
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: 320, height: section == 0 && self.goals.count > 0 ? 5 : 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let row = (indexPath as NSIndexPath).row
        if row < self.goals.count { self.openGoal(self.goals[row]) }
    }

    @objc func openGoalFromNotification(_ notification: Notification) {
        let slug = (notification as NSNotification).userInfo!["slug"] as! String
        let matchingGoal = self.goals.filter({ (jsonGoal) -> Bool in
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

