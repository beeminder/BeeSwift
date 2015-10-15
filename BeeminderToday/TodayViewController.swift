//
//  TodayViewController.swift
//  BeeSwift
//
//  Created by Andy Brett on 10/13/15.
//  Copyright © 2015 APB. All rights reserved.
//

import Foundation
import UIKit
import AFNetworking
import SnapKit

class TodayViewControler: UIViewController {
    
    var button = UIButton()
    var graph = UIImageView()
    
    override func viewDidLoad() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateLabelText", name: NSUserDefaultsDidChangeNotification, object: nil)
        let defaults = NSUserDefaults(suiteName: "group.beeminder.beeminder")
        self.button.setTitle(defaults?.objectForKey("todayString") as? String, forState: .Normal)
        let goalURLs = defaults?.objectForKey("todayURLs") as! Array<String>
        
        self.view.addSubview(self.graph)
        self.graph.snp_makeConstraints { (make) -> Void in
            make.height.equalTo(100)
            make.width.equalTo(100)
            make.left.equalTo(0)
            make.top.equalTo(0)
        }
        graph.setImageWithURL(NSURL(string: goalURLs.first!)!, placeholderImage: UIImage(named: "GraphPlaceholder"))
    }
    
    func updateLabelText() {
        let defaults = NSUserDefaults(suiteName: "group.beeminder.beeminder")
        self.button.setTitle(defaults?.objectForKey("todayString") as? String, forState: .Normal)
    }
}

//@implementation TodayViewController
//
//- (void)viewDidLoad {
//    [super viewDidLoad];
//    
//    [self updateLabelText];
//    [[NSNotificationCenter defaultCenter] addObserver:self
//    selector:@selector(updateLabelText)
//    name:NSUserDefaultsDidChangeNotification
//    object:nil];
//    self.button.titleLabel.numberOfLines = 0;
//    [self.button addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
//    
//    
//    }
//    
//    - (void)buttonPressed
//        {
//            [self.extensionContext openURL:[NSURL URLWithString:@"beeminder://"] completionHandler:nil];
//        }
//        
//        - (void)didReceiveMemoryWarning {
//            [super didReceiveMemoryWarning];
//            // Dispose of any resources that can be recreated.
//            }
//            
//            - (void)updateLabelText {
//                NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.beeminder.beeminder"];
//                [self.button setTitle:[defaults objectForKey:@"todayString"] forState:UIControlStateNormal];
//                }
//                
//                - (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
//                    // Perform any setup necessary in order to update the view.
//                    
//                    // If an error is encountered, use NCUpdateResultFailed
//                    // If there's no update required, use NCUpdateResultNoData
//                    // If there's an update, use NCUpdateResultNewData
//                    
//                    completionHandler(NCUpdateResultNewData);
//}