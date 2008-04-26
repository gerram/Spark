/*
 *  SparkFunctions.m
 *  SparkKit
 *
 *  Created by Black Moon Team.
 *  Copyright (c) 2004 - 2007 Shadow Lab. All rights reserved.
 */

#import <SparkKit/SparkFunctions.h>

#import <SparkKit/SparkAlert.h>
#import <SparkKit/SparkPrivate.h>
#import <SparkKit/SparkMultipleAlerts.h>

#import WBHEADER(WBIconView.h)
#import WBHEADER(WBImageView.h)
#import WBHEADER(WBBezelItem.h)
#import WBHEADER(WBAEFunctions.h)
#import WBHEADER(WBProcessFunctions.h)

#pragma mark Utilities
BOOL SparkEditorIsRunning(void) {
  ProcessSerialNumber psn = WBProcessGetProcessWithSignature(kSparkEditorSignature);
  return psn.lowLongOfPSN != kNoProcess;
}

BOOL SparkDaemonIsRunning(void) {
  ProcessSerialNumber psn = WBProcessGetProcessWithSignature(kSparkDaemonSignature);
  return psn.lowLongOfPSN != kNoProcess;
}

void SparkLaunchEditor() {
  switch (SparkGetCurrentContext()) {
    case kSparkEditorContext:
      [NSApp activateIgnoringOtherApps:NO];
      break;
    case kSparkDaemonContext: {
      ProcessSerialNumber psn = WBProcessGetProcessWithSignature(kSparkEditorSignature);
      if (psn.lowLongOfPSN != kNoProcess) {
        SetFrontProcess(&psn);
        WBAESendSimpleEvent(kSparkEditorSignature, kCoreEventClass, kAEReopenApplication);
      } else {
#if defined(DEBUG)
        NSString *sparkPath = @"./Spark.app";
#else
        NSString *sparkPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"../../../"];
#endif  
        if ([NSThread respondsToSelector:@selector(isMainThread)] && [NSThread isMainThread]) {
          [[NSWorkspace sharedWorkspace] launchApplication:[sparkPath stringByStandardizingPath]];
        } else {
          [[NSWorkspace sharedWorkspace] performSelectorOnMainThread:@selector(launchApplication:) withObject:[sparkPath stringByStandardizingPath] waitUntilDone:NO];
        }
      }
    }
      break;
  }
}

SparkContext SparkGetCurrentContext() {
  static SparkContext ctxt = 0xffffffff;
  if (ctxt != 0xffffffff) return ctxt;
  
  @synchronized(@"SparkContextLock") {
    if (0xffffffff == ctxt) {
      CFBundleRef bundle = CFBundleGetMainBundle();
      if (bundle) {
        CFStringRef ident = CFBundleGetIdentifier(bundle);
        if (ident) {
          if (CFEqual((CFTypeRef)kSparkDaemonBundleIdentifier, ident)) {
            ctxt = kSparkDaemonContext;
          } else {
            ctxt = kSparkEditorContext;
          }
        }
      }
    } 
  }
  return ctxt;
}

#pragma mark Alerts
void SparkDisplayAlerts(NSArray *items) {
  if ([items count] == 1) {
    SparkAlert *alert = [items objectAtIndex:0];
    NSString *ok = NSLocalizedStringFromTableInBundle(@"OK", nil, kSparkKitBundle , @"OK");
    
    NSString *other = [alert hideSparkButton] ? nil : NSLocalizedStringFromTableInBundle(@"LAUNCH_SPARK_BUTTON", nil,
                                                                                         kSparkKitBundle, @"Open Spark Alert Button");
    [NSApp activateIgnoringOtherApps:YES];
    if (NSRunAlertPanel([alert messageText],[alert informativeText], ok, nil, other) == NSAlertOtherReturn) {
      SparkLaunchEditor();
    }
  }
  else if ([items count] > 1) {
    id alerts = [[SparkMultipleAlerts alloc] initWithAlerts:items];
    [alerts showAlerts];
    [alerts autorelease];
  }  
}

#pragma mark Notifications

static 
WBBezelItem *_SparkNotifiationSharedItem() {
  static WBBezelItem *_shared = nil;
  if (!_shared) {
    _shared = [[WBBezelItem alloc] initWithContent:nil];
    [_shared setAdjustSize:NO];
  }
  return _shared;
}

static 
WBIconView *_SparkNotificationSharedIconView() {
  static WBIconView *_shared = nil;
  if (!_shared) {
    _shared = [[WBIconView alloc] initWithFrame:NSMakeRect(0, 0, 128, 128)];
  }
  return _shared;
}

static 
NSImageView *_SparkNotificationSharedImageView() {
  static WBImageView *_shared = nil;
  if (!_shared) {
    _shared = [[WBImageView alloc] initWithFrame:NSMakeRect(0, 0, 128, 128)];
    [_shared setEditable:NO];
    [_shared setImageFrameStyle:NSImageFrameNone];
    [_shared setImageAlignment:NSImageAlignCenter];
    [_shared setImageScaling:NSScaleProportionally];
    [_shared setImageInterpolation:NSImageInterpolationHigh];
  }
  return _shared;
}

void SparkNotificationDisplay(NSView *view, CGFloat delay) {
  WBBezelItem *item = _SparkNotifiationSharedItem();
  [item setContent:view];
  [item setDelay:delay];
  [item display:nil];
}

void SparkNotificationDisplayIcon(IconRef icon, CGFloat delay) {
  WBIconView *view = _SparkNotificationSharedIconView();
  [view setIconRef:icon];
  SparkNotificationDisplay(view, delay);
}

void SparkNotificationDisplayImage(NSImage *anImage, CGFloat delay) {
  NSImageView *view = _SparkNotificationSharedImageView();
  [view setImage:anImage];
  SparkNotificationDisplay(view, delay);
}

void SparkNotificationDisplaySystemIcon(OSType icon, CGFloat delay) {
  WBIconView *view = _SparkNotificationSharedIconView();
  [view setSystemIcon:icon];
  SparkNotificationDisplay(view, delay);
}
