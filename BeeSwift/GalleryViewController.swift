//
//  GalleryViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/19/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import UIKit
import AFNetworking
import MagicalRecord
import SnapKit
import MBProgressHUD

class GalleryViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, UICollectionViewDataSource {
    
    private var hasFetchedData = false
    var collectionView :UICollectionView?
    var collectionViewLayout :UICollectionViewLayout?
    let lastUpdatedView = UIView()
    let lastUpdatedLabel = BSLabel()
    let cellReuseIdentifier = "Cell"
    var refreshControl = UIRefreshControl()
    var deadbeatView = UIView()
    
    var frontburnerGoals : [Goal] = []
    var backburnerGoals  : [Goal] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleSignIn", name: CurrentUserManager.signedInNotificationName, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleSignOut", name: CurrentUserManager.signedOutNotificationName, object: nil)
        
        self.collectionViewLayout = UICollectionViewFlowLayout()
        self.collectionView = UICollectionView(frame: self.view.frame, collectionViewLayout: self.collectionViewLayout!)
        self.collectionView?.backgroundColor = UIColor.whiteColor()
        self.collectionView?.registerClass(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "footer")
        self.view.backgroundColor = UIColor.whiteColor()
        self.title = "Goals"
        
        let item = UIBarButtonItem(image: UIImage(named: "Settings"), style: UIBarButtonItemStyle.Plain, target: self, action: "settingsButtonPressed")
        self.navigationItem.rightBarButtonItem = item
        
        self.loadGoalsFromDatabase()
        
        self.view.addSubview(self.lastUpdatedView)
        self.lastUpdatedView.backgroundColor = UIColor.beeGrayColor()
        self.lastUpdatedView.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.snp_topLayoutGuideBottom)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.lastUpdatedView.addSubview(self.lastUpdatedLabel)
        self.lastUpdatedLabel.text = "Last updated:"
        self.lastUpdatedLabel.font = UIFont(name: "Avenir", size: Constants.defaultFontSize)
        self.lastUpdatedLabel.textAlignment = NSTextAlignment.Center
        self.lastUpdatedLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(3)
            make.bottom.equalTo(-3)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.updateLastUpdatedLabel()
        NSTimer.scheduledTimerWithTimeInterval(60, target: self, selector: "updateLastUpdatedLabel", userInfo: nil, repeats: true)
        
        self.view.addSubview(self.deadbeatView)
        self.deadbeatView.backgroundColor = UIColor.beeGrayColor()
        self.deadbeatView.snp_makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(self.lastUpdatedView.snp_bottom)
            if !CurrentUserManager.sharedManager.isDeadbeat() {
                make.height.equalTo(0)
            }
        }
        
        let deadbeatLabel = BSLabel()
        self.deadbeatView.addSubview(deadbeatLabel)
        deadbeatLabel.textColor = UIColor.redColor()
        deadbeatLabel.numberOfLines = 0
        deadbeatLabel.font = UIFont(name: "Avenir-Heavy", size: 13)
        deadbeatLabel.text = "Hey! Beeminder couldn't charge your credit card, so you can't see your graphs. Please update your card on beeminder.com or email support@beeminder.com if this is a mistake."
        deadbeatLabel.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(3)
            make.bottom.equalTo(-3)
            make.left.equalTo(10)
            make.right.equalTo(-10)
        }
        
        self.collectionView!.delegate = self
        self.collectionView!.dataSource = self
        self.collectionView!.registerClass(GoalCollectionViewCell.self, forCellWithReuseIdentifier: self.cellReuseIdentifier)
        self.view.addSubview(self.collectionView!)
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl.addTarget(self, action: "fetchData:", forControlEvents: UIControlEvents.ValueChanged)
        self.collectionView!.addSubview(self.refreshControl)
        
        self.collectionView!.snp_makeConstraints { (make) -> Void in
            make.top.equalTo(self.deadbeatView.snp_bottom)
            make.left.equalTo(0)
            make.bottom.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.fetchData(self.refreshControl)
    }
    
    override func viewDidAppear(animated: Bool) {
        if !CurrentUserManager.sharedManager.signedIn() {
            self.presentViewController(SignInViewController(), animated: true, completion: nil)
        }
        else if !self.hasFetchedData {
//            let hud = MBProgressHUD.showHUDAddedTo(self.view, animated: true)
//            hud.mode = .Indeterminate
            self.fetchData(nil)
        }
    }
    
    func settingsButtonPressed() {
        self.navigationController?.pushViewController(SettingsViewController(), animated: true)
    }
    
    func handleSignIn() {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func handleSignOut() {
        self.frontburnerGoals = []
        self.backburnerGoals = []
        self.collectionView?.reloadData()
        self.hasFetchedData = false
    }
    
    func updateDeadbeatHeight() {
        self.deadbeatView.snp_remakeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(self.lastUpdatedView.snp_bottom)
            if !CurrentUserManager.sharedManager.isDeadbeat() {
                make.height.equalTo(0)
            }
        }
    }
    
    func updateLastUpdatedLabel() {
        if let lastSynced = DataSyncManager.sharedManager.lastSynced {
            if lastSynced.timeIntervalSinceNow < -3600 {
                let lastText :NSMutableAttributedString = NSMutableAttributedString(string: "Last updated: more than an hour ago")
                lastText.addAttribute(NSForegroundColorAttributeName, value: UIColor.redColor(), range: NSRange(location: 0, length: lastText.string.characters.count))
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
            lastText.addAttribute(NSForegroundColorAttributeName, value: UIColor.redColor(), range: NSRange(location: 0, length: lastText.string.characters.count))
            self.lastUpdatedLabel.attributedText = lastText
        }
    }
    
    func fetchData(refreshControl: UIRefreshControl?) {
        DataSyncManager.sharedManager.fetchData({ () -> Void in
            self.loadGoalsFromDatabase()
            self.collectionView!.reloadData()
            self.updateLastUpdatedLabel()
            self.updateDeadbeatHeight()
            self.hasFetchedData = true
//            MBProgressHUD.hideAllHUDsForView(self.view, animated: true)
            if refreshControl != nil {
                refreshControl!.endRefreshing()
            }
            }, error: { () -> Void in
//                MBProgressHUD.hideAllHUDsForView(self.view, animated: true)                
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
        self.frontburnerGoals = Goal.MR_findAllWithPredicate(NSPredicate(format: "burner = %@ and serverDeleted = false", "frontburner")) as! [Goal]
        self.frontburnerGoals = self.frontburnerGoals.sort { ($0.losedate < $1.losedate) }
        self.backburnerGoals  = Goal.MR_findAllWithPredicate(NSPredicate(format: "burner = %@ and serverDeleted = false", "backburner")) as! [Goal]
        self.backburnerGoals = self.backburnerGoals.sort { ($0.losedate < $1.losedate) }
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? self.frontburnerGoals.count : self.backburnerGoals.count
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSizeMake(320, 120)
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell:GoalCollectionViewCell = self.collectionView!.dequeueReusableCellWithReuseIdentifier(self.cellReuseIdentifier, forIndexPath: indexPath) as! GoalCollectionViewCell
        
        let goal:Goal = indexPath.section == 0 ? self.frontburnerGoals[indexPath.row] : self.backburnerGoals[indexPath.row]
        
        cell.goal = goal
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionFooter {
            let footer = self.collectionView?.dequeueReusableSupplementaryViewOfKind(UICollectionElementKindSectionFooter, withReuseIdentifier: "footer", forIndexPath: indexPath) as UICollectionReusableView!
            footer.backgroundColor = UIColor.beeGrayColor()
            return footer
        }
        return UICollectionReusableView()
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSizeMake(320, section == 0 && self.frontburnerGoals.count > 0 ? 5 : 0)
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let goalViewController = GoalViewController()
        if indexPath.section == 0 {
            goalViewController.goal = self.frontburnerGoals[indexPath.row]
        }
        else {
            goalViewController.goal = self.backburnerGoals[indexPath.row]
        }

        self.navigationController?.pushViewController(goalViewController, animated: true)
    }

}

