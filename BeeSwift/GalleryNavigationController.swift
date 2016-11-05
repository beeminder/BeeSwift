//
//  GalleryNavigationController.swift
//  BeeSwift
//
//  Created by Andy Brett on 4/24/15.
//  Copyright (c) 2015 APB. All rights reserved.
//

import Foundation

class GalleryNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        self.navigationBar.barStyle = UIBarStyle.black
        self.navigationBar.barTintColor = UIColor.black
        self.navigationBar.tintColor = UIColor.white
//
//        let titleDict: NSDictionary = [NSForegroundColorAttributeName: UIColor.whiteColor()]
//        self.navigationBar.titleTextAttributes = titleDict as [NSObject : AnyObject]
    }
    
}
