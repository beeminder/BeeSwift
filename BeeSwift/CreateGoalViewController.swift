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
        
        let url = URL.init(string: "\(BSHTTPSessionManager.sharedManager.baseURLString)/api/v1/users/me.json?access_token=\(CurrentUserManager.sharedManager.accessToken!)&redirect_to_url=\(BSHTTPSessionManager.sharedManager.baseURLString)/new")
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
}
