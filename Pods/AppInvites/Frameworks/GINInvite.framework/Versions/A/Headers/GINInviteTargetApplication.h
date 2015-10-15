//
//  GINInviteTargetApplication.h
//  Google App Invite SDK
//
//  Copyright 2015 Google Inc.
//
//  Use of this SDK is subject to the Google APIs Terms of Service:
//  https://developers.google.com/terms
//
//  Detailed instructions to use this SDK can be found at:
//  https://developers.google.com/app-invites
//

#import <Foundation/Foundation.h>

// A user may send app invites from iOS to users on other platforms, for e.g., users on Android.
// Use |GINInviteTargetApplication| to specify the non-iOS application that must be installed or
// opened when a user acts on an app invite on that platform.
@interface GINInviteTargetApplication : NSObject

// The Android client ID from the Google API console project.
@property(nonatomic, copy) NSString *androidClientID;

@end
