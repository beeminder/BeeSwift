#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "Sentry.h"
#import "SentryBreadcrumb.h"
#import "SentryClient.h"
#import "SentryCrashExceptionApplication.h"
#import "SentryDebugMeta.h"
#import "SentryDefines.h"
#import "SentryDsn.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryError.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryFrame.h"
#import "SentryHub.h"
#import "SentryId.h"
#import "SentryIntegrationProtocol.h"
#import "SentryMechanism.h"
#import "SentryMessage.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#import "SentrySDK.h"
#import "SentrySdkInfo.h"
#import "SentrySerializable.h"
#import "SentrySession.h"
#import "SentryStacktrace.h"
#import "SentryThread.h"
#import "SentryUser.h"
#import "SentryUserFeedback.h"

FOUNDATION_EXPORT double SentryVersionNumber;
FOUNDATION_EXPORT const unsigned char SentryVersionString[];

