//
//  GINInviteError.h
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

// Error domain for errors returned by the invite dialog.
extern NSString *const kGINInviteErrorDomain;

// Possible error codes returned by the invite dialog.
typedef NS_ENUM(NSInteger, GINInviteErrorCode) {
  kGINInviteErrorCodeUnknown = -400,
  kGINInviteErrorCodeCanceled = -401,
  kGINInviteErrorCodeCanceledByUser = -402,
  kGINInviteErrorCodeLaunchError = -403,
  kGINInviteErrorCodeSignInError = -404,
  kGINInviteErrorCodeServerError = -490,
  kGINInviteErrorCodeNetworkError = -491,
  kGINInviteErrorCodeSMSError = -492,
  kGINInviteErrorCodeInvalidParameters = -497,
};

