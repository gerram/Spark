//
//  SystemAction.m
//  Spark
//
//  Created by Fox on Wed Feb 18 2004.
//  Copyright (c) 2004 Shadow Lab. All rights reserved.
//

#import "SystemAction.h"

#import <ShadowKit/SKFunctions.h>
#import <ShadowKit/SKFSFunctions.h>
#import <ShadowKit/SKAEFunctions.h>
#import <ShadowKit/SKIOKitFunctions.h>

static NSString * const 
kFastUserSwitcherPath = @"/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession";
static NSString * const 
kScreenSaverEngine = @"/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine";

NSString * const
kSystemActionBundleIdentifier = @"org.shadowlab.spark.system";

static 
void SystemFastLogOut(void);

static 
NSString * const kSystemActionKey = @"SystemAction";
static
NSString * const kSystemConfirmKey = @"SystemConfirm";

@implementation SystemAction

#pragma mark Protocols Implementation
- (id)copyWithZone:(NSZone *)zone {
  SystemAction* copy = [super copyWithZone:zone];
  copy->sa_action = sa_action;
  copy->sa_saFlags = sa_saFlags;
  return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [super encodeWithCoder:coder];
  [coder encodeInt:[self action] forKey:kSystemActionKey];
  [coder encodeBool:sa_saFlags.confirm forKey:kSystemConfirmKey];
  return;
}

- (id)initWithCoder:(NSCoder *)coder {
  if (self = [super initWithCoder:coder]) {
    [self setAction:[coder decodeIntForKey:kSystemActionKey]];
    [self setShouldConfirm:[coder decodeBoolForKey:kSystemConfirmKey]];
  }
  return self;
}

#pragma mark -
#pragma mark Required Methods.
- (id)initWithSerializedValues:(NSDictionary *)plist {
  if (self = [super initWithSerializedValues:plist]) {
    [self setAction:[[plist objectForKey:kSystemActionKey] intValue]];
  }
  return self;
}

- (BOOL)serialize:(NSMutableDictionary *)plist {
  if ([super serialize:plist]) {
    [plist setObject:SKInt([self action]) forKey:kSystemActionKey];
    return YES;
  }
  return NO;
}

- (SystemActionType)action {
  return sa_action;
}

- (void)setAction:(SystemActionType)newAction {
  sa_action = newAction;
}

- (SparkAlert *)check {
  switch ([self action]) {
    case kSystemLogOut:
    case kSystemSleep:
    case kSystemRestart:
    case kSystemShutDown:
    case kSystemFastLogOut:
    case kSystemScreenSaver:
      /* Accessibility */
    case kSystemSwitchPolarity:
    case kSystemSwitchGrayscale:
      /* System Event */
//    case kSystemMute:
//    case kSystemEject:
//    case kSystemVolumeUp:
//    case kSystemVolumeDown:
      return nil;
    default:
      return [SparkAlert alertWithMessageText:NSLocalizedStringFromTableInBundle(@"INVALID_ACTION_ALERT",
                                                                                 nil,
                                                                                 kSystemActionBundle,
                                                                                 @"Error When trying to execute but Action unknown ** Title **")
                    informativeTextWithFormat:NSLocalizedStringFromTableInBundle(@"INVALID_ACTION_ALERT_MSG",
                                                                                 nil,
                                                                                 kSystemActionBundle,
                                                                                 @"Error When trying to execute but Action unknown ** Msg **")];
  }
}

- (SparkAlert *)execute {
  SparkAlert *alert = [self check];
  if (alert == nil) {
    switch ([self action]) {
      case kSystemLogOut:
        [self logout];
        break;
      case kSystemSleep:
        SKHIDPostSystemDefinedEvent(kSKHIDSleepEvent);
        //        [self sleep];
        break;
      case kSystemRestart:
        SKHIDPostSystemDefinedEvent(kSKHIDRestartEvent);
        //        [self restart];
        break;
      case kSystemShutDown:
        SKHIDPostSystemDefinedEvent(kSKHIDShutdownEvent);
        //        [self shutDown];
        break;
      case kSystemFastLogOut:
        [self fastLogout];
        break;
      case kSystemScreenSaver:
        [self screenSaver];
        break;
        /* Accessibility */
      case kSystemSwitchPolarity:
        [self togglePolarity];
        break;
      case kSystemSwitchGrayscale:
        [self toggleGray];
        break;
//      case kSystemMute:
//        SKHIDPostAuxKey(kSKKeyMute);
//        break;
//      case kSystemEject:
//        SKHIDPostAuxKey(kSKKeyEject);
//        //SKHIDPostSystemDefinedEvent(kSKHIDEjectKey);
//        break;
//      case kSystemVolumeUp:
//        SKHIDPostAuxKey(kSKKeySoundUp);
//        break;
//      case kSystemVolumeDown:
//        SKHIDPostAuxKey(kSKKeySoundDown);
//        break;
    }
  }
  return alert;
}

#pragma mark -
extern Boolean CGDisplayUsesForceToGray();
extern void CGDisplayForceToGray(Boolean gray);

extern Boolean CGDisplayUsesInvertedPolarity();
extern void CGDisplaySetInvertedPolarity(Boolean inverted);

- (void)toggleGray {
  CGDisplayForceToGray(!CGDisplayUsesForceToGray());
}

- (void)togglePolarity {
  CGDisplaySetInvertedPolarity(!CGDisplayUsesInvertedPolarity());
}

/*
kAELogOut                     = 'logo',
kAEReallyLogOut               = 'rlgo',
kAEShowRestartDialog          = 'rrst',
kAEShowShutdownDialog         = 'rsdn'
 */
- (void)logout {
  ProcessSerialNumber psn = {0, kSystemProcess};
  SKAESendSimpleEventToProcess(&psn, kCoreEventClass, [self shouldConfirm] ? kAELogOut : kAEReallyLogOut);
}

- (void)sleep {
  ProcessSerialNumber psn = {0, kSystemProcess};
  SKAESendSimpleEventToProcess(&psn, kCoreEventClass, 'slep');
}

- (void)restart {
  ProcessSerialNumber psn = {0, kSystemProcess};
  SKAESendSimpleEventToProcess(&psn, kCoreEventClass, [self shouldConfirm] ? kAEShowRestartDialog : 'rest');
}

- (void)shutDown {
  ProcessSerialNumber psn = {0, kSystemProcess};
  SKAESendSimpleEventToProcess(&psn, kCoreEventClass, [self shouldConfirm] ? kAEShowShutdownDialog : 'shut');
}

- (BOOL)shouldConfirm {
  return sa_saFlags.confirm;
}
- (void)setShouldConfirm:(BOOL)flag {
  SKSetFlag(sa_saFlags.confirm, flag);
}

- (void)fastLogout {
  SystemFastLogOut();
}

- (void)screenSaver {
  if (SKSystemMajorVersion() >= 10 && SKSystemMinorVersion() >= 4) {
    FSRef engine;
    if ([kScreenSaverEngine getFSRef:&engine]) {
      LSLaunchFSRefSpec spec;
      memset(&spec, 0, sizeof(spec));
      spec.appRef = &engine;
      spec.launchFlags = kLSLaunchDefaults;
      LSOpenFromRefSpec(&spec, nil);
//      LSApplicationParameters parameters;
//      memset(&parameters, 0, sizeof(parameters));
//      parameters.application = &engine;
//      LSOpenApplication(&parameters, nil);
    }
  }
}

@end

static 
void SystemFastLogOut() {
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:kFastUserSwitcherPath];
  [task setArguments:[NSArray arrayWithObject:@"-suspend"]];
  [task launch];
  [task waitUntilExit];
  [task release];
}

#pragma mark -
@interface PowerAction : SparkAction {
}
@end

@implementation PowerAction

- (id)initWithSerializedValues:(NSDictionary *)plist {
  [self release];
  if (self = [[SystemAction alloc] initWithSerializedValues:plist]) {
    [self setAction:[[plist objectForKey:@"PowerAction"] intValue]];
  }
  return self;
}

@end

