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

class GalleryViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, UICollectionViewDataSource {
    
    fileprivate var hasFetchedData = false
    var collectionView :UICollectionView?
    var collectionViewLayout :UICollectionViewLayout?
    let lastUpdatedView = UIView()
    let lastUpdatedLabel = BSLabel()
    let cellReuseIdentifier = "Cell"
    let newGoalCellReuseIdentifier = "NewGoalCell"
    var refreshControl = UIRefreshControl()
    var deadbeatView = UIView()
    
    var goals : [Goal] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleSignIn), name: NSNotification.Name(rawValue: CurrentUserManager.signedInNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleSignOut), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleWillReset), name: NSNotification.Name(rawValue: CurrentUserManager.willResetNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleReset), name: NSNotification.Name(rawValue: CurrentUserManager.resetNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.openGoalFromNotification(_:)), name: NSNotification.Name(rawValue: "openGoal"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleCreateGoalButtonPressed), name: NSNotification.Name(rawValue: "createGoalButtonPressed"), object: nil)
        
        self.collectionViewLayout = UICollectionViewFlowLayout()
        self.collectionView = UICollectionView(frame: self.view.frame, collectionViewLayout: self.collectionViewLayout!)
        self.collectionView?.backgroundColor = UIColor.white
        self.collectionView?.alwaysBounceVertical = true
        self.collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "footer")
        self.view.backgroundColor = UIColor.white
        self.title = "Goals"
        
        let item = UIBarButtonItem(image: UIImage(named: "Settings"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(GalleryViewController.settingsButtonPressed))
        self.navigationItem.rightBarButtonItem = item
        
        self.loadGoalsFromDatabase()
        
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
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: #selector(self.fetchData(_:)), for: UIControlEvents.valueChanged)
        self.collectionView!.addSubview(self.refreshControl)
        
        self.collectionView!.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.deadbeatView.snp.bottom)
            make.left.equalTo(0)
            make.bottom.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.fetchData(self.refreshControl)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !CurrentUserManager.sharedManager.signedIn() {
            self.present(SignInViewController(), animated: true, completion: nil)
        }
        else if !self.hasFetchedData {
            self.fetchData(nil)
        }
    }
    
    func settingsButtonPressed() {
        self.navigationController?.pushViewController(SettingsViewController(), animated: true)
    }
    
    func handleSignIn() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func handleSignOut() {
        self.goals = []
        self.collectionView?.reloadData()
        self.hasFetchedData = false
    }
    
    func handleWillReset() {
        self.goals = []
        self.collectionView?.reloadData()
    }
    
    func handleReset() {
        self.fetchData(nil)
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
    
    func handleCreateGoalButtonPressed() {
        self.navigationController?.pushViewController(CreateGoalViewController(), animated: true)
    }
    
    func updateLastUpdatedLabel() {
        if let lastSynced = DataSyncManager.sharedManager.lastSynced {
            if lastSynced.timeIntervalSinceNow < -3600 {
                let lastText :NSMutableAttributedString = NSMutableAttributedString(string: "Last updated: more than an hour ago")
                lastText.addAttribute(NSForegroundColorAttributeName, value: UIColor.red, range: NSRange(location: 0, length: lastText.string.characters.count))
                self.lastUpdatedLabel.attributedText = lastText
            }
            else if lastSynced.timeIntervalSinceNow < -120 {
                self.lastUpdatedLabel.text = "Last updated: \(-1*Int(lastSynced.timeIntervalSinceNow/60)) minutes ago"
            }
            else if lastSynced.timeIntervalSinceNow < -60 {
                self.lastUpdatedLabel.text = "Last updated: 1 minute ago"
            }
            else {
                self.lastUpdatedLabel.text = "Last updated: less than a minute ago"
            }
        }
        else {
            let lastText :NSMutableAttributedString = NSMutableAttributedString(string: "Last updated: a long time ago...")
            lastText.addAttribute(NSForegroundColorAttributeName, value: UIColor.red, range: NSRange(location: 0, length: lastText.string.characters.count))
            self.lastUpdatedLabel.attributedText = lastText
        }
    }
    
    func fetchData(_ refreshControl: UIRefreshControl?) {
        if self.goals.count == 0 {
            MBProgressHUD.showAdded(to: self.view, animated: true)
        }
        DataSyncManager.sharedManager.fetchData({ () -> Void in
            let isRegisteredForNotifications = UIApplication.shared.currentUserNotificationSettings?.types.contains(UIUserNotificationType.alert) ?? false
            if !isRegisteredForNotifications {
                RemoteNotificationsManager.sharedManager.turnNotificationsOn()
            }
            self.loadGoalsFromDatabase()
            self.collectionView!.reloadData()
            self.updateLastUpdatedLabel()
            self.updateDeadbeatHeight()
            self.hasFetchedData = true
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            if refreshControl != nil {
                refreshControl!.endRefreshing()
            }
            }, error: { () -> Void in              
                if refreshControl != nil {
                    refreshControl!.endRefreshing()
                }
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadGoalsFromDatabase() {
        self.goals = Goal.mr_findAll(with: NSPredicate(format: "serverDeleted = false")) as! [Goal]
        self.goals = self.goals.sorted { ($0.losedate.intValue < $1.losedate.intValue) }
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
        
        let goal:Goal = self.goals[(indexPath as NSIndexPath).row]
        
        cell.goal = goal
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: 320, height: section == 0 && self.goals.count > 0 ? 5 : 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.openGoal(self.goals[(indexPath as NSIndexPath).row])
    }

    func openGoalFromNotification(_ notification: Notification) {
        let slug = (notification as NSNotification).userInfo!["slug"] as! String
        guard let goal = Goal.mr_findFirst(byAttribute: "slug", withValue: slug) else {
            return
        }
        self.navigationController?.popToRootViewController(animated: false)
        self.openGoal(goal)
    }
    
    func openGoal(_ goal: Goal) {
        let goalViewController = GoalViewController()
        goalViewController.goal = goal
        self.navigationController?.pushViewController(goalViewController, animated: true)
    }
}

