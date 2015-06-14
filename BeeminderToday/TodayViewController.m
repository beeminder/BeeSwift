//
//  TodayViewController.m
//  BeeminderToday
//
//  Created by Andy Brett on 3/22/15.
//  Copyright (c) 2015 Andy Brett. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>

@interface TodayViewController () <NCWidgetProviding>

@end

@implementation TodayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self updateLabelText];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateLabelText)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];
    self.button.titleLabel.numberOfLines = 0;
    [self.button addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
    // Do any additional setup after loading the view from its nib.
}

- (void)buttonPressed
{
    [self.extensionContext openURL:[NSURL URLWithString:@"Beeminder://"] completionHandler:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)updateLabelText {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.beeminder.beeminder"];
    [self.button setTitle:[defaults objectForKey:@"todayString"] forState:UIControlStateNormal];
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData

    completionHandler(NCUpdateResultNewData);
}

@end
