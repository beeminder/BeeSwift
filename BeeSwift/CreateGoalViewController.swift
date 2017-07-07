//
//  CreateGoalViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 7/6/17.
//  Copyright © 2017 APB. All rights reserved.
//

import UIKit
import SnapKit

class CreateGoalViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let webView = UIWebView()
        self.view.addSubview(webView)
        webView.snp.makeConstraints { (make) in
            make.edges.equalTo(0)
        }
        let url = URL.init(string: "\(BSHTTPSessionManager.sharedManager.baseURLString)/api/v1/users/me.json?access_token=\(CurrentUserManager.sharedManager.accessToken!)&redirect_to_url=\(BSHTTPSessionManager.sharedManager.baseURLString)/new")
        webView.loadRequest(URLRequest(url: url!))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
