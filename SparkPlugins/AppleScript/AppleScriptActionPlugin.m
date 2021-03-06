/*
 *  AppleScriptActionPlugin.m
 *  Spark Plugins
 *
 *  Created by Black Moon Team.
 *  Copyright (c) 2004 - 2007, Shadow Lab. All rights reserved.
 */

#import "AppleScriptActionPlugin.h"
#import "AppleScriptAction.h"

#import <OSAKit/OSAKit.h>

#import <WonderBox/WBAlias.h>
#import <WonderBox/WBAEFunctions.h>
#import <WonderBox/WBLSFunctions.h>

enum {
  kAppleScriptFileTab   = 1,
  kAppleScriptSourceTab = 0,
};

@implementation AppleScriptActionPlugin

- (void)loadSparkAction:(AppleScriptAction *)sparkAction toEdit:(BOOL)edit {
  WBAlias *alias;
  NSString *source;
  [[ibScriptController scriptView] setSource:@""];
  if ((alias = sparkAction.scriptBookmark)) {
    [self setScriptFile:alias.path];
    [self setValue:@(kAppleScriptFileTab) forKey:@"selectedTab"];
  } else if ((source = sparkAction.scriptSource)) {
    [[ibScriptController scriptView] setSource:source];
    [ibScriptController compileScript:nil];
  }
}

- (NSAlert *)checkSyntax {
  NSAlert *alert = nil;
  if (![[[ibScriptController scriptView] source] length]) {
    alert = [NSAlert alertWithMessageText:NSLocalizedStringFromTableInBundle(@"CREATE_ACTION_WITHOUT_SOURCE_ALERT", nil, AppleScriptActionBundle,
                                                                             @"Empty Source Error * Title *")
                            defaultButton:NSLocalizedStringWithDefaultValue(@"OK", nil, AppleScriptActionBundle, @"OK",
                                                                            @"Alert default button")
                          alternateButton:nil
                              otherButton:nil
                informativeTextWithFormat:NSLocalizedStringFromTableInBundle(@"CREATE_ACTION_WITHOUT_SOURCE_ALERT_MSG", nil, AppleScriptActionBundle,
                                                                             @"Empty Source Error * Msg *")];
  } else {
    OSAScript *script = [ibScriptController script];//[ alloc] initWithSource:[ibScript source]];
		if (!script)
			script = [[OSAScript alloc] initWithSource:[[ibScriptController scriptView] source]];
    if (!script) {
			alert = [NSAlert alertWithMessageText:NSLocalizedStringFromTableInBundle(@"SCRIPT_CREATION_ERROR_ALERT", nil, AppleScriptActionBundle,
																																							 @"Unknow Error in -initWithSource * Title *")
															defaultButton:NSLocalizedStringWithDefaultValue(@"OK", nil, AppleScriptActionBundle, @"OK",
																																							@"Alert default button")
                              alternateButton:nil
																otherButton:nil
									informativeTextWithFormat:NSLocalizedStringFromTableInBundle(@"SCRIPT_CREATION_ERROR_ALERT_MSG", nil, AppleScriptActionBundle,
																																							 @"Unknow Error in -initWithSource * Msg *")];
    } else {
      alert = [self compileScript:script];
			if (!alert)
				[ibScriptController compileScript:nil];
		}
  }
  return alert;
}

- (NSAlert *)sparkEditorShouldConfigureAction {
  NSAlert *alert = nil;
  switch (_selectedTab) {
    case kAppleScriptSourceTab:
      alert = [self checkSyntax];
      break;
    case kAppleScriptFileTab:
      if (![self scriptFile]) {
        alert = [NSAlert alertWithMessageText:NSLocalizedStringFromTableInBundle(@"CREATE_ACTION_WITHOUT_FILE", nil,
                                                                                 AppleScriptActionBundle,
                                                                                 @"Trying to create Script File Action without file * Title *")
                                defaultButton:NSLocalizedStringWithDefaultValue(@"OK", nil,
                                                                                 AppleScriptActionBundle, @"OK",
                                                                                 @"Alert default button")
                              alternateButton:nil
                                  otherButton:nil
                    informativeTextWithFormat:NSLocalizedStringFromTableInBundle(@"CREATE_ACTION_WITHOUT_FILE_MSG", nil,
                                                                                 AppleScriptActionBundle,
                                                                                 @"Trying to create Script File Action without file * Msg *")];
      }
      break;
  }
  return alert;
}

- (void)configureAction {
  AppleScriptAction *action = [self sparkAction];
  
  switch (_selectedTab) {
    case kAppleScriptSourceTab:
      [action setScriptSource:[[ibScriptController scriptView] source]];
      [action setFile:nil];
      break;
    case kAppleScriptFileTab:
      [action setScriptSource:nil];
      [action setFile:[self scriptFile]];
      break;
  }
  
  [action setIcon:nil];
  [action setActionDescription:AppleScriptActionDescription(action)];
}

#pragma mark Compile
- (NSAlert *)alertForScriptError:(NSDictionary *)errors {
  int error = [[errors objectForKey:OSAScriptErrorNumber] intValue];
  if (-128 == error) {
    //=> User Cancel
    return nil;
  }
  NSString *title = [errors objectForKey:OSAScriptErrorBriefMessage];
  NSString *message = [errors objectForKey:OSAScriptErrorMessage];
  
  NSRange range = [[errors objectForKey:OSAScriptErrorRange] rangeValue];
  [[ibScriptController scriptView] setSelectedRange:range];
  
  return [NSAlert alertWithMessageText:title
                         defaultButton:NSLocalizedStringWithDefaultValue(@"OK", nil, AppleScriptActionBundle, @"OK",
                                                                         @"Alert default button")
                       alternateButton:nil
                           otherButton:nil
             informativeTextWithFormat:@"%@", message];
}

- (NSAlert *)compileScript:(OSAScript *)script {
  NSAlert *alert = nil;
  NSDictionary *error = nil;
  if (![script compileAndReturnError:&error]) {
    alert = [self alertForScriptError:error];
    if (![alert messageText])
      [alert setMessageText:NSLocalizedStringFromTableInBundle(@"SYNTAX_ERROR_ALERT", nil, AppleScriptActionBundle,
                                                               @"Syntax Error * Title *")];
  }
  return alert;
}

#pragma mark Open
- (IBAction)open:(id)sender {
  NSOpenPanel *oPanel = [NSOpenPanel openPanel];
  [oPanel setAllowsMultipleSelection:NO];
  [oPanel setCanChooseDirectories:NO];
  [oPanel setResolvesAliases:YES];
  [oPanel beginSheetModalForWindow:[[self actionView] window] completionHandler:^(NSInteger result) {
    if (result == NSOKButton && [[oPanel URLs] count] > 0) {
      NSURL *file = [[oPanel URLs] objectAtIndex:0];
      NSString *src = nil;
      if ([[[file pathExtension] lowercaseString] isEqualToString:@"scpt"]) {
        OSAScript *script = [[OSAScript alloc] initWithContentsOfURL:file error:nil];
        src = [script source];
      } else {
        NSStringEncoding encoding;
        src = [[NSString alloc] initWithContentsOfURL:file usedEncoding:&encoding error:NULL];
      }
      [[self->ibScriptController scriptView] setSource:src];
    }
  }];
}

#pragma mark Import
- (IBAction)import:(id)sender {
  NSOpenPanel *oPanel = [NSOpenPanel openPanel];  
  [oPanel setAllowsMultipleSelection:NO];
  [oPanel setCanChooseDirectories:NO];
  [oPanel setResolvesAliases:YES];
  oPanel.allowedFileTypes = @[@"scpt", @"osas"];
  [oPanel beginSheetModalForWindow:[[self actionView] window] completionHandler:^(NSInteger result) {
    if (result == NSOKButton && [[oPanel URLs] count] > 0) {
      NSDictionary *errors = nil;
      NSURL *file = [oPanel URLs].firstObject;
      NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:file error:&errors];
      [oPanel close];
      if (![script isCompiled]) {
        NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"INVALID_SCRIPT_FILE_ALERT", nil, AppleScriptActionBundle,
                                                             @"Import uncompiled Script Error * Title *"),
                          NSLocalizedStringWithDefaultValue(@"OK", nil, AppleScriptActionBundle, @"OK",
                                                            @"Alert default button"),
                          nil,nil, [[self actionView] window], nil ,nil, nil, nil,
                          NSLocalizedStringFromTableInBundle(@"INVALID_SCRIPT_FILE_ALERT_MSG", nil, AppleScriptActionBundle,
                                                             @"Import uncompiled Script Error * Msg *"), [file lastPathComponent]);
      } else {
        [self setScriptFile:[file path]];
      }
    } else {
      [self setScriptFile:nil];
    }
  }];
}

#pragma mark Launch
- (IBAction)launchEditor:(id)sender {
  OSStatus err = noErr;
  NSString *src = nil;
  AppleEvent aevt = WBAEEmptyDesc();
  AEDesc document = WBAEEmptyDesc();
  
  /* Launch Script Editor */
  NSRunningApplication *editor = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.ScriptEditor2"].firstObject;
  if (!editor) {
    NSURL *url = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.apple.ScriptEditor2"];
    editor = url ? [[NSWorkspace sharedWorkspace] launchApplicationAtURL:url options:NSWorkspaceLaunchDefault configuration:nil error:NULL] : nil;
  }
  if (!editor)
    return;

  /* activate */
  err = WBAESendSimpleEventTo(editor.processIdentifier, kAEMiscStandards, kAEActivate);
  require_noerr(err, dispose);
  
  src = [[ibScriptController scriptView] source];
  if (!src || ![src length]) {
    return;
  }
  
  /* set the_document to make document */
  err = WBAECreateEventWithTargetProcessIdentifier(editor.processIdentifier, kAECoreSuite, kAECreateElement, &aevt);
  require_noerr(err, dispose);
  
  OSType type = cDocument;
  err = WBAEAddAEDescWithData(&aevt, keyAEObjectClass, typeType, &type, sizeof(OSType));
  require_noerr(err, dispose);
  
//  err = WBAESetStandardAttributes(&aevt);
//  require_noerr(err, dispose);
  
  err = WBAESendEventReturnAEDesc(&aevt, typeObjectSpecifier, &document);
  WBAEDisposeDesc(&aevt);
  require_noerr(err, dispose);
  
  /* set text of the_document to 'src' */
  err = WBAECreateEventWithTargetProcessIdentifier(editor.processIdentifier, kAECoreSuite, kAESetData, &aevt);
  require_noerr(err, dispose);
  
  err = WBAEAddIndexObjectSpecifier(&aevt, keyDirectObject, 'ctxt', kAEAll, &document);
  require_noerr(err, dispose);
  
  err = WBAEAddStringAsUnicodeText(&aevt, keyAEData, SPXNSToCFString(src));
  require_noerr(err, dispose);
  
  err = WBAESendEventNoReply(&aevt);
  require_noerr(err, dispose);
  
dispose:
    WBAEDisposeDesc(&aevt);
  WBAEDisposeDesc(&document);
}

@end
