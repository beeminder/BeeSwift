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
import SafariServices
import OSLog

import BeeKit


class GalleryViewController: UIViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, UICollectionViewDataSource, UISearchBarDelegate, SFSafariViewControllerDelegate {
    let logger = Logger(subsystem: "com.beeminder.beeminder", category: "GalleryViewController")

    var collectionView :UICollectionView?
    var collectionViewLayout :UICollectionViewFlowLayout?
    let lastUpdatedView = UIView()
    let lastUpdatedLabel = BSLabel()
    let cellReuseIdentifier = "Cell"
    var deadbeatView = UIView()
    var outofdateView = UIView()
    let noGoalsLabel = BSLabel()
    let outofdateLabel = BSLabel()
    let searchBar = UISearchBar()
    var lastUpdated: Date?
    let maxSearchBarHeight: Int = 50
    
    var goals : Array<BeeGoal> = []
    var filteredGoals : Array<BeeGoal> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleSignIn), name: NSNotification.Name(rawValue: CurrentUserManager.signedInNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleSignOut), name: NSNotification.Name(rawValue: CurrentUserManager.signedOutNotificationName), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.openGoalFromNotification(_:)), name: NSNotification.Name(rawValue: "openGoal"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleGoalsFetchedNotification), name: NSNotification.Name(rawValue: GoalManager.goalsUpdatedNotificationName), object: nil)
        
        self.collectionViewLayout = UICollectionViewFlowLayout()
        self.collectionView = UICollectionView(frame: self.view.frame, collectionViewLayout: self.collectionViewLayout!)
        self.collectionView?.backgroundColor = .systemBackground
        self.collectionView?.alwaysBounceVertical = true
        self.collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "footer")

        self.view.backgroundColor = .systemBackground
        self.title = "Goals"
        
        let item = UIBarButtonItem(image: UIImage(named: "Settings"), style: UIBarButtonItem.Style.plain, target: self, action: #selector(self.settingsButtonPressed))
        self.navigationItem.rightBarButtonItem = item
        
        self.view.addSubview(self.lastUpdatedView)
        self.lastUpdatedView.backgroundColor = UIColor.beeminder.gray
        self.lastUpdatedView.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin)
            make.left.equalTo(0)
            make.right.equalTo(0)
        }
        
        self.lastUpdatedView.addSubview(self.lastUpdatedLabel)
        self.lastUpdatedLabel.text = "Last updated:"
        self.lastUpdatedLabel.font = UIFont.beeminder.defaultFontPlain.withSize(Constants.defaultFontSize)
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
        self.deadbeatView.backgroundColor = UIColor.beeminder.gray
        self.deadbeatView.snp.makeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(self.lastUpdatedView.snp.bottom)
            if !ServiceLocator.currentUserManager.isDeadbeat() {
                make.height.equalTo(0)
            }
        }
        
        let deadbeatLabel = BSLabel()
        self.deadbeatView.addSubview(deadbeatLabel)
        deadbeatLabel.textColor = .beeminder.red
        deadbeatLabel.numberOfLines = 0
        deadbeatLabel.font = UIFont.beeminder.defaultFontHeavy.withSize(13)
        deadbeatLabel.text = "Hey! Beeminder couldn't charge your credit card, so you can't see your graphs. Please update your card on beeminder.com or email support@beeminder.com if this is a mistake."
        deadbeatLabel.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(3)
            make.bottom.equalTo(-3)
            make.left.equalTo(10)
            make.right.equalTo(-10)
        }
        
        self.view.addSubview(self.outofdateView)
        self.outofdateView.backgroundColor = UIColor.beeminder.gray
        self.outofdateView.snp.makeConstraints { (make) in
            make.right.left.equalTo(0)
            make.top.equalTo(self.deadbeatView.snp.bottom)
            make.height.equalTo(0)
        }
        
        self.outofdateView.addSubview(self.outofdateLabel)
        self.outofdateLabel.textColor = .beeminder.red
        self.outofdateLabel.numberOfLines = 0
        self.outofdateLabel.font = UIFont.beeminder.defaultFontHeavy.withSize(12)
        self.outofdateLabel.textAlignment = .center
        self.outofdateLabel.snp.makeConstraints { (make) in
            make.top.equalTo(3)
            make.bottom.equalTo(-3)
            make.left.equalTo(10)
            make.right.equalTo(-10)
        }
        
        self.view.addSubview(self.searchBar)
        self.searchBar.delegate = self
        self.searchBar.placeholder = "Filter goals by slug"
        self.searchBar.isHidden = true
        self.searchBar.showsCancelButton = true
        self.searchBar.snp.makeConstraints { (make) in
            make.left.right.equalTo(0)
            make.top.equalTo(self.outofdateView.snp.bottom)
            make.height.equalTo(0)
        }
        
        self.collectionView!.delegate = self
        self.collectionView!.dataSource = self
        self.collectionView!.register(GoalCollectionViewCell.self, forCellWithReuseIdentifier: self.cellReuseIdentifier)
        self.view.addSubview(self.collectionView!)
        
        self.collectionView?.refreshControl = {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(self.fetchGoals), for: UIControl.Event.valueChanged)
            return refreshControl
        }()
        
        self.collectionView!.snp.makeConstraints { (make) -> Void in
            make.top.equalTo(self.searchBar.snp.bottom)
            make.left.equalTo(self.view.safeAreaLayoutGuide.snp.leftMargin)
            make.right.equalTo(self.view.safeAreaLayoutGuide.snp.rightMargin)
            make.bottom.equalTo(0)
        }
        
        self.view.addSubview(self.noGoalsLabel)
        self.noGoalsLabel.snp.makeConstraints { (make) in
            make.top.left.right.equalTo(self.collectionView!)
        }
        self.noGoalsLabel.text = "You have no Beeminder goals!\n\nYou'll need to create one before this app will be any use."
        self.noGoalsLabel.textAlignment = .center
        self.noGoalsLabel.numberOfLines = 0
        self.noGoalsLabel.isHidden = true
        
        self.fetchGoals()
        

        
        if ServiceLocator.currentUserManager.signedIn() {
            UNUserNotificationCenter.current().requestAuthorization(options: UNAuthorizationOptions([.alert, .badge, .sound])) { (success, error) in
                print(success)
                if success {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }

        Task { @MainActor in
            do {
                let updateState = try await ServiceLocator.versionManager.updateState()

                switch updateState {
                case .UpdateRequired:
                    self.outofdateView.snp.remakeConstraints { (make) -> Void in
                        make.left.equalTo(0)
                        make.right.equalTo(0)
                        make.top.equalTo(self.deadbeatView.snp.bottom)
                        make.height.equalTo(42)
                    }
                    self.outofdateLabel.isHidden = false
                    self.outofdateLabel.text = "This version of the Beeminder app is no longer supported.\n Please update to the newest version in the App Store."
                    self.collectionView?.isHidden = true
                case .UpdateSuggested:
                    self.outofdateView.snp.remakeConstraints { (make) -> Void in
                        make.left.equalTo(0)
                        make.right.equalTo(0)
                        make.top.equalTo(self.deadbeatView.snp.bottom)
                        make.height.equalTo(42)
                    }
                    self.outofdateLabel.isHidden = false
                    self.outofdateLabel.text = "There is a new version of the Beeminder app in the App Store.\nPlease update when you have a moment."
                    self.collectionView?.isHidden = false
                case .UpToDate:
                    self.collectionView?.isHidden = false
                }
            } catch let error as VersionError {
                logger.error("Error checking for current version: \(error)")
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !ServiceLocator.currentUserManager.signedIn() {
            let signInVC = SignInViewController()
            signInVC.modalPresentationStyle = .fullScreen
            self.present(signInVC, animated: true, completion: nil)
        } else {
            self.goals = ServiceLocator.goalManager.staleGoals() ?? []
            self.collectionView!.reloadData()
        }
        self.fetchGoals()
    }
    
    @objc func handleGoalsFetchedNotification() {
        Task {
            self.goals = ServiceLocator.goalManager.staleGoals() ?? []
            self.lastUpdated = await ServiceLocator.goalManager.goalsFetchedAt
            self.didFetchGoals()
        }
    }
    
    @objc func settingsButtonPressed() {
        self.navigationController?.pushViewController(SettingsViewController(), animated: true)
    }
    
    @objc func searchButtonPressed() {
        self.toggleSearchBar()
    }
    
    private func toggleSearchBar() {
        self.searchBar.isHidden.toggle()
        
        if searchBar.isHidden {
            self.searchBar.text = ""
            self.filteredGoals = self.goals
            self.searchBar.resignFirstResponder()
            self.collectionView?.reloadData()
        } else {
            self.searchBar.becomeFirstResponder()
        }
        
        self.updateSearchBarConstraints()
    }
    
    private func updateSearchBarConstraints() {
        self.searchBar.snp.remakeConstraints { (make) in
            make.left.right.equalTo(0)
            make.top.equalTo(self.outofdateView.snp.bottom)
            if self.searchBar.isHidden {
                make.height.equalTo(0)
            } else {
                make.height.equalTo(self.maxSearchBarHeight)
            }
        }
    }
    
    @objc func userDefaultsDidChange() {
        DispatchQueue.main.async {
            self.sortGoals()
            self.collectionView?.reloadData()
        }
    }
    
    @objc func handleSignIn() {
        self.dismiss(animated: true, completion: nil)
        self.fetchGoals()
        
        UNUserNotificationCenter.current().requestAuthorization(options: UNAuthorizationOptions([.alert, .badge, .sound])) { (success, error) in
            print(success)
        }
    }
    
    @objc func handleSignOut() {
        self.goals = []
        self.filteredGoals = []
        self.collectionView?.reloadData()
        if self.presentedViewController != nil {
            if type(of: self.presentedViewController!) == SignInViewController.self { return }
        }
        let signInVC = SignInViewController()
        signInVC.modalPresentationStyle = .fullScreen
        self.present(signInVC, animated: true, completion: nil)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.updateFilteredGoals(searchText: searchText)
        self.collectionView?.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text else { return }
        self.searchBar.resignFirstResponder()
        self.updateFilteredGoals(searchText: searchText)
        self.collectionView?.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.toggleSearchBar()
    }
    
    func updateFilteredGoals(searchText : String) {
        if searchText == "" {
            self.filteredGoals = self.goals
        } else {
        self.filteredGoals = self.goals.filter { (goal) -> Bool in
                return goal.slug.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    func updateDeadbeatHeight() {
        self.deadbeatView.snp.remakeConstraints { (make) -> Void in
            make.left.equalTo(0)
            make.right.equalTo(0)
            make.top.equalTo(self.lastUpdatedView.snp.bottom)
            if !ServiceLocator.currentUserManager.isDeadbeat() {
                make.height.equalTo(0)
            }
        }
    }
    
    @objc func updateLastUpdatedLabel() {
        var lastTextString = ""
        var color = UIColor.black
        if let lastUpdated = self.lastUpdated {
            if lastUpdated.timeIntervalSinceNow < -3600 {
                color = .beeminder.red
                lastTextString = "Last updated: a long time ago..."
            }
            else if lastUpdated.timeIntervalSinceNow < -120 {
                color = UIColor.black
                lastTextString = "Last updated: \(-1 * Int(lastUpdated.timeIntervalSinceNow / 60)) minutes ago"
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
            color = .beeminder.red
            lastTextString = "Last updated: a long time ago..."
        }
        let lastText: NSMutableAttributedString = NSMutableAttributedString(string: lastTextString)
        lastText.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: NSRange(location: 0, length: lastText.string.count))
        self.lastUpdatedLabel.attributedText = lastText
    }
    
    @objc func didFetchGoals() {
        self.sortGoals()
        self.setupHealthKit()
        self.collectionView?.refreshControl?.endRefreshing()
        MBProgressHUD.hide(for: self.view, animated: true)
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
        let searchItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(self.searchButtonPressed))
        self.navigationItem.leftBarButtonItem = searchItem
    }
    
    func setupHealthKit() {
        Task { @MainActor in
            do {
                try await ServiceLocator.healthStoreManager.ensureUpdatesRegularly(goals: self.goals)
            } catch {
                // We should display an error UI
            }
        }
    }
    
    @objc func fetchGoals() {
        Task { @MainActor in
            if self.goals.count == 0 {
                MBProgressHUD.showAdded(to: self.view, animated: true)
            }

            do {
                let goals = try await ServiceLocator.goalManager.fetchGoals()
                self.goals = goals
                self.updateFilteredGoals(searchText: self.searchBar.text ?? "")
                self.didFetchGoals()
            } catch {
                if UIApplication.shared.applicationState == .active {
                    let alert = UIAlertController(title: "Error fetching goals", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
                self.collectionView?.refreshControl?.endRefreshing()
                MBProgressHUD.hide(for: self.view, animated: true)
                self.collectionView!.reloadData()
            }
        }
    }
    
    func sortGoals() {
        self.goals.sort(by: { (goal1, goal2) -> Bool in
            if let selectedGoalSort = UserDefaults.standard.value(forKey: Constants.selectedGoalSortKey) as? String {
                if selectedGoalSort == Constants.nameGoalSortString {
                    return goal1.slug < goal2.slug
                }
                else if selectedGoalSort == Constants.recentDataGoalSortString {
                    return goal1.lasttouch?.intValue ?? 0 > goal2.lasttouch?.intValue ?? 0
                }
                else if selectedGoalSort == Constants.pledgeGoalSortString {
                    return goal1.pledge.intValue > goal2.pledge.intValue
                }
            }

            // urgencykey is guaranteed to result in goals sorting into the canonical order
            return goal1.urgencykey < goal2.urgencykey
        })
        self.updateFilteredGoals(searchText: self.searchBar.text ?? "")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return ServiceLocator.versionManager.lastChckedUpdateState() == .UpdateRequired ? 0 : self.filteredGoals.count
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let minimumWidth: CGFloat = 320

        let availableWidth = self.collectionView!.frame.width - self.collectionView!.contentInset.left - self.collectionView!.contentInset.right
        let itemSpacing = self.collectionViewLayout!.minimumInteritemSpacing

        // Calculate how many cells could fit at the minimum width, rounding down (as we can't show a fractional cell)
        // We need to account for there being margin between cells, so there is 1 fewer margin than cell. We do this by
        // imagining there is some non-showed spacing after the final cell. For example with wo cells:
        // | available width in parent | spacing |
        // |  cell  | spacing |  cell  | spacing |
        let cellsWhileMaintainingMinimumWidth = Int(
            (availableWidth + itemSpacing) /
            (minimumWidth + itemSpacing)
        )

        // Calculate how wide a cell can be. This can be larger than our minimum width because we
        // may have rounded down the number of cells. E.g. if we could have fit 1.5 minimum width
        // cells we will only show 1, but can make it 50% wider than minimum
        let targetWidth = (availableWidth + itemSpacing) / CGFloat(cellsWhileMaintainingMinimumWidth) -  self.collectionViewLayout!.minimumInteritemSpacing

        return CGSize(width: targetWidth, height: 120)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell:GoalCollectionViewCell = self.collectionView!.dequeueReusableCell(withReuseIdentifier: self.cellReuseIdentifier, for: indexPath) as! GoalCollectionViewCell
        
        let goal:BeeGoal = self.filteredGoals[(indexPath as NSIndexPath).row]
        
        cell.goal = goal
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        return CGSize(width: 320, height: section == 0 && self.goals.count > 0 ? 5 : 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let row = (indexPath as NSIndexPath).row
        if row < self.filteredGoals.count { self.openGoal(self.filteredGoals[row]) }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // After a rotation or other size change the optimal width for our cells may have changed.
        // We instruct the collectionView to reload so widths are recalculated.
        coordinator.animate { _ in } completion: { _ in
            self.collectionView?.reloadData()
        }
    }

    @objc func openGoalFromNotification(_ notification: Notification) {
        let slug = (notification as NSNotification).userInfo!["slug"] as! String
        let matchingGoal = self.goals.filter({ (goal) -> Bool in
            return goal.slug == slug
        }).last
        if matchingGoal != nil {
            self.navigationController?.popToRootViewController(animated: false)
            self.openGoal(matchingGoal!)
        }
    }
    
    func openGoal(_ goal: BeeGoal) {
        let goalViewController = GoalViewController()
        goalViewController.goal = goal
        self.navigationController?.pushViewController(goalViewController, animated: true)
    }
    
    // MARK: - SFSafariViewControllerDelegate
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true, completion: nil)
        self.fetchGoals()
    }
}

