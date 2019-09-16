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

class CreateGoalViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webView = UIWebView()
        self.view.addSubview(webView)
        webView.snp.makeConstraints { (make) in
            make.edges.equalTo(0)
        }
        webView.delegate = self
        
        let url = URL.init(string: "\(RequestManager.baseURLString)/api/v1/users/\(CurrentUserManager.sharedManager.username!).json?access_token=\(CurrentUserManager.sharedManager.accessToken!)&redirect_to_url=\(RequestManager.baseURLString)/new?ios=true")
        webView.loadRequest(URLRequest(url: url!))
    }
    
    func doneButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension CreateGoalViewController: UIWebViewDelegate {
    func webViewDidStartLoad(_ webView: UIWebView) {
        MBProgressHUD.showAdded(to: self.view, animated: true)
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
        let alert = UIAlertController(title: "Error creating a goal", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
