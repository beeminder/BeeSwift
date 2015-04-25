//
//  GoalViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class GoalViewController: UIViewController {
    
    var goal :Goal!

    override func viewDidLoad() {
        self.view.backgroundColor = UIColor.whiteColor()
        self.title = self.goal.title
    }
}