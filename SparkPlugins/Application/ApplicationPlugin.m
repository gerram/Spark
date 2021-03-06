/*
 *  ApplicationPlugin.m
 *  Spark Plugins
 *
 *  Created by Black Moon Team.
 *  Copyright (c) 2004 - 2007, Shadow Lab. All rights reserved.
 */

#import "ApplicationPlugin.h"

#import <WonderBox/WBApplication.h>
#import <WonderBox/WBImageView.h>
#import <WonderBox/WBImageFunctions.h>
#import <WonderBox/NSImage+WonderBox.h>

@implementation ApplicationPlugin {
@private
  NSString *aa_name;
  ApplicationVisualSetting aa_settings;
}

#pragma mark -
- (void)loadSparkAction:(ApplicationAction *)sparkAction toEdit:(BOOL)edit {
  [self willChangeValueForKey:@"visual"];
  [self willChangeValueForKey:@"notifyLaunch"];
  [self willChangeValueForKey:@"notifyActivation"];
  if ([sparkAction usesSharedVisual]) {
    [ApplicationAction getSharedSettings:&aa_settings];
  } else {
    [sparkAction getVisualSettings:&aa_settings];
  }
  [self didChangeValueForKey:@"notifyActivation"];
  [self didChangeValueForKey:@"notifyLaunch"];
  [self didChangeValueForKey:@"visual"];
  if (edit) {
    [self setPath:[sparkAction path]];
    [self setFlags:[sparkAction flags]];
    [self setAction:[sparkAction action]];
  } else {
    [self setAction:kApplicationLaunch];
  }
  [ibName setStringValue:[sparkAction name] ? : @""];
}

- (NSAlert *)sparkEditorShouldConfigureAction {
  switch ([self action]) {
    case kApplicationHideFront:
    case kApplicationHideOther:
    case kApplicationForceQuitFront:
    case kApplicationForceQuitDialog:
      break;
    default:
      if (!_path)
        return [NSAlert alertWithMessageText:NSLocalizedStringFromTableInBundle(@"CREATE_ACTION_WITHOUT_APPLICATION_ALERT", nil, kApplicationActionBundle,
                                                                                @"Create Action without Application Error * Title *")
                               defaultButton:NSLocalizedStringFromTableInBundle(@"OK", nil, kApplicationActionBundle,
                                                                                @"Alert default button")
                             alternateButton:nil
                                 otherButton:nil
                   informativeTextWithFormat:NSLocalizedStringFromTableInBundle(@"CREATE_ACTION_WITHOUT_APPLICATION_ALERT_MSG", nil, kApplicationActionBundle,
                                                                                @"Create Action without Application Error * Msg *")];
  }
  return nil;
}

- (void)configureAction {
  [super configureAction];
  ApplicationAction *action = [self sparkAction];
  [action setFlags:_flags];
  
  /* Save visual if needed */
  if (![action usesSharedVisual]) {
    [action setVisualSettings:&aa_settings];
  }
  
  switch ([self action]) {
    case kApplicationHideFront:
    case kApplicationHideOther:
    case kApplicationForceQuitFront:
    case kApplicationForceQuitDialog:
      [action setPath:nil];
      [action setIcon:ApplicationActionIcon(action)];
      break;
    default: {
      [action setPath:_path];
      NSImage *icon = [[ibIcon image] copy];
      if (icon) {
        WBImageSetRepresentationsSize(icon, NSMakeSize(16, 16));
        [action setIcon:icon];
      }
    }
  }
  if ([ibName stringValue] && [[ibName stringValue] length])
    [action setName:[ibName stringValue]];
  else
    [action setName:[[ibName cell] placeholderString]]; 
  
  [action setActionDescription:ApplicationActionDescription(action, [[action application] name])];
}

- (void)plugInViewWillBecomeHidden {
  if ([[self sparkAction] usesSharedVisual]) {
    // Update defaut configuration
    [ApplicationAction setSharedSettings:&aa_settings];
  }
}

#pragma mark -
- (IBAction)back:(id)sender {
  [ibTab selectTabViewItemAtIndex:0];
}
- (IBAction)options:(id)sende {
  [ibTab selectTabViewItemAtIndex:1];
}

- (IBAction)chooseApplication:(id)sender {
  NSOpenPanel *oPanel = [NSOpenPanel openPanel];
  
  [oPanel setCanChooseDirectories:NO];
  [oPanel setAllowsMultipleSelection:NO];
  
  NSString *directory = [_path stringByDeletingLastPathComponent];
  NSString *file = [_path lastPathComponent];
  [oPanel beginSheetForDirectory:directory
                            file:file
                           types:[NSArray arrayWithObjects:@"app", @"APPL", nil]
                  modalForWindow:[sender window]
                   modalDelegate:self
                  didEndSelector:@selector(choosePanel:returnCode:contextInfo:)
                     contextInfo:nil];
}

- (void)choosePanel:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
  if (returnCode == NSOKButton && [[sheet filenames] count] > 0) {
    [self setPath:[[sheet filenames] objectAtIndex:0]];
  }
}

#pragma mark -
- (void)setPath:(NSString *)aPath {
  SPXSetterCopyAndDo(_path, aPath, {
    NSString *name = [[[NSFileManager defaultManager] displayNameAtPath:aPath] stringByDeletingPathExtension];
    [ibApplication setStringValue:name ? : @""];
    [[ibName cell] setPlaceholderString:name ? : NSLocalizedStringFromTableInBundle(@"ACTION_NAME",
                                                                                    NULL, kApplicationActionBundle, 
                                                                                    @"Action Name Placeholder")];
    NSImage *icon;
    if (aPath) {
      icon = [[NSWorkspace sharedWorkspace] iconForFile:aPath];
      //if (icon) {
      //      WBImageSetRepresentationsSize(icon, [ibIcon bounds].size);
      //      [icon setSize:[ibIcon bounds].size];
      //    }
    } else {
      icon = [NSImage imageNamed:@"AAUndefined" inBundle:SPXCurrentBundle()];
    }
    [ibIcon setImage:icon];
  });
}

- (ApplicationActionType)action {
  return [(ApplicationAction *)[self sparkAction] action];
}

- (void)setAction:(ApplicationActionType)newAction {
	[self willChangeValueForKey:@"showOptions"];
	[self willChangeValueForKey:@"showChooser"];
  [(ApplicationAction *)[self sparkAction] setAction:newAction];
	[self didChangeValueForKey:@"showChooser"];
	[self didChangeValueForKey:@"showOptions"];

  /* Update placeholder */
  switch (newAction) {
    case kApplicationHideFront:
    case kApplicationHideOther: 
    case kApplicationForceQuitFront:
    case kApplicationForceQuitDialog:
      [[ibName cell] setPlaceholderString:ApplicationActionDescription([self sparkAction], nil)];
      break;
    default: {
      NSString *name = [ibApplication stringValue];
      [[ibName cell] setPlaceholderString:[name length] > 0 ? name : NSLocalizedStringFromTableInBundle(@"ACTION_NAME",
                                                                                                        NULL, kApplicationActionBundle, 
                                                                                                        @"Action Name Placeholder")];
      break;
    }
  }
}

- (BOOL)showChooser {
	switch ([self action]) {
		case kApplicationQuit:
		case kApplicationLaunch:
    case kApplicationToggle:
		case kApplicationActivateQuit:
    case kApplicationForceQuitAppli:
			return YES;
		case kApplicationHideFront:
    case kApplicationHideOther:
    case kApplicationForceQuitFront:
    case kApplicationForceQuitDialog:
			return NO;
	}
	return NO;
}

- (BOOL)showOptions {
	switch ([self action]) {
		case kApplicationLaunch:
    case kApplicationToggle:
		case kApplicationActivateQuit:
			return YES;
		case kApplicationQuit:
		case kApplicationHideFront:
    case kApplicationHideOther:
    case kApplicationForceQuitAppli:
    case kApplicationForceQuitFront:
    case kApplicationForceQuitDialog:
			return NO;
	}
	return NO;
}

- (NSInteger)visual {
  return [[self sparkAction] usesSharedVisual] ? 0 : 1;
}
- (void)setVisual:(NSInteger)visual {
  BOOL shared = [[self sparkAction] usesSharedVisual];
  [self willChangeValueForKey:@"notifyLaunch"];
  [self willChangeValueForKey:@"notifyActivation"];
  switch (visual) {
    case 0: // Shared visual
      if (!shared) {
        [[self sparkAction] setUsesSharedVisual:YES];
        [[self sparkAction] setVisualSettings:&aa_settings];
        [ApplicationAction getSharedSettings:&aa_settings];
      }
      break;
    case 1: // This action only
      if (shared) {
        [[self sparkAction] setUsesSharedVisual:NO];
        [ApplicationAction setSharedSettings:&aa_settings];
        [[self sparkAction] getVisualSettings:&aa_settings];
      }
  }
  [self didChangeValueForKey:@"notifyActivation"];
  [self didChangeValueForKey:@"notifyLaunch"];
}

- (BOOL)notifyLaunch {
  return aa_settings.launch;
}
- (void)setNotifyLaunch:(BOOL)flag {
  aa_settings.launch = flag;
}
- (BOOL)notifyActivation {
  return aa_settings.activation;
}
- (void)setNotifyActivation:(BOOL)flag {
  aa_settings.activation = flag;
}

#pragma mark -
#pragma mark Flags Manipulation
- (void)setFlags:(LSLaunchFlags)value {
  [self setHide:(value & kLSLaunchAndHide) != 0];
  [self setDontSwitch:(value & kLSLaunchDontSwitch) != 0];
  [self setNewInstance:(value & kLSLaunchNewInstance) != 0];
  [self setHideOthers:(value & kLSLaunchAndHideOthers) != 0];
}

- (BOOL)dontSwitch {
  return (_flags & kLSLaunchDontSwitch) != 0;
}
- (void)setDontSwitch:(BOOL)dontSwitch {
  _flags = dontSwitch ? _flags | kLSLaunchDontSwitch : _flags & ~kLSLaunchDontSwitch;
}

- (BOOL)newInstance {
  return (_flags & kLSLaunchNewInstance) != 0;
}
- (void)setNewInstance:(BOOL)newInstance {
  _flags = newInstance ? _flags | kLSLaunchNewInstance : _flags & ~kLSLaunchNewInstance;
}

- (BOOL)hide {
  return (_flags & kLSLaunchAndHide) != 0;
}
- (void)setHide:(BOOL)hide {
  _flags = hide ? _flags | kLSLaunchAndHide : _flags & ~kLSLaunchAndHide;
}

- (BOOL)hideOthers {
  return (_flags & kLSLaunchAndHideOthers) != 0;
}
- (void)setHideOthers:(BOOL)hideOthers {
  _flags = hideOthers ? _flags | kLSLaunchAndHideOthers : _flags & ~kLSLaunchAndHideOthers;
}

#pragma mark -
- (BOOL)hasCustomView {
  return YES;
}

+ (NSImage *)plugInViewIcon {
  return [NSImage imageNamed:@"AAApplication" inBundle:kApplicationActionBundle];
}

@end
