//
//  CreateGoalViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 7/6/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit
import SnapKit
import MBProgressHUD
import WebKit

class CreateGoalViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webView = WKWebView()
        self.view.addSubview(webView)
        webView.snp.makeConstraints { (make) in
            make.edges.equalTo(0)
        }
        webView.navigationDelegate = self
        
        let url = URL.init(string: "\(RequestManager.baseURLString)/api/v1/users/\(CurrentUserManager.sharedManager.username!).json?access_token=\(CurrentUserManager.sharedManager.accessToken!)&redirect_to_url=\(RequestManager.baseURLString)/new?ios=true")
        webView.load(URLRequest(url: url!))
    }
    
    func doneButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension CreateGoalViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        MBProgressHUD.showAdded(to: self.view, animated: true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
        let alert = UIAlertController(title: "Error creating a goal", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
