//
//  Spark.m
//  Spark
//
//  Created by Fox on Fri Dec 12 2003.
//  Copyright (c) 2004 Shadow Lab. All rights reserved.
//

#if defined (DEBUG)
#warning Debug defined in Spark!

#import <Foundation/NSDebug.h>
#import "ChoosePanel.h"
#import "AppActionEditor.h"
#endif

#import "Spark.h"

#import <SparkKit/SparkKit.h>

#import "Extensions.h"
#import "Preferences.h"
#import "SparkImporter.h"
#import "PluginInstaller.h"
#import "KeyLibraryController.h"
#import "LibraryWindowController.h"
#import "InspectorController.h"
#import "PluginHelpController.h"
#import "ScriptHandler.h"
#import "ServerController.h"

int main(int argc, const char *argv[]) {
#ifdef DEBUG
  NSDebugEnabled = YES;
  NSHangOnUncaughtException = YES;
//  SparkLibraryFileFormat = NSPropertyListXMLFormat_v1_0;
#endif
  return NSApplicationMain(argc, argv);
}

#pragma mark -
@implementation Spark

#pragma mark Init And Destroy
- (id)init {
  if (self = [super init]) { 
#if defined (DEBUG)
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
      @"YES", @"NSShowNonLocalizedStrings",
      //@"YES", @"NSShowAllViews",
      //@"6", @"NSDragManagerLogLevel",
      //@"YES", @"NSShowNonLocalizableStrings",
      //@"1", @"NSScriptingDebugLogLevel",
      nil]];
#endif
    [[KVBSparkObjectList class] poseAsClass:[SparkObjectList class]];
    [[CheckActiveSparkHotKey class] poseAsClass:[SparkHotKey class]];
    
    SparkDefaultLibrary(); // Chargement de la biblioth�que
    [ServerController start]; // D�marrage de la connexion avec le serveur
    [self setServerState:[ServerController serverState]]; // Analyse de l'�tat du serveur
    [Preferences checkVersion];
    [Preferences verifyAutoStart];
    [Preferences setDefaultsValues];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [libraryWindow release];
  [prefWindows release];
  [plugInHelpWindow release];
  [super dealloc];
}

- (void)awakeFromNib {
#if defined (DEBUG)
  [self createDebugMenu];
#endif
  [self createAboutMenu];
  [self openLibraryWindow:nil]; // Ouvre la fen�tre principale (Library.nib)
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sparkDidChangePlugIn:) name:kSparkDidAddPlugInNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sparkDidChangePlugIn:) name:kSparkDidRemovePlugInNotification object:nil];
}

#pragma mark -
#pragma mark Menu IBActions
- (IBAction)startStopServer:(id)sender {
  if ([self serverState] != kSparkDaemonStarted) {
    [[ServerController sharedController] startServer];
  }
  else {
    [[ServerController sharedController] shutDownServer];
  }
}

- (IBAction)openInspector:(id)sender {
  [[InspectorController sharedInspector] showWindow:nil];
}

- (IBAction)openPreferences:(id)sender {
  if (!prefWindows) {
    prefWindows = [[Preferences alloc] init];
  }
  if (libraryWindow) {
    [NSApp beginSheet: [prefWindows window]
       modalForWindow: [libraryWindow window]
        modalDelegate: nil
       didEndSelector: nil
          contextInfo: nil];
  }
}

- (IBAction)openLibraryWindow:(id)sender {
  if (!libraryWindow) {
    libraryWindow = [[LibraryWindowController alloc] init];
    [[libraryWindow window] setDelegate:self];
  }
  [libraryWindow showWindow:nil];
}

#pragma mark -
#pragma mark Import/Export Support

- (IBAction)importLibrary:(id)sender {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setCanChooseDirectories:NO];
  [panel setCanCreateDirectories:NO];
  [panel setAllowsMultipleSelection:NO];
  int result = [panel runModalForTypes:[NSArray arrayWithObjects:
    kSparkLibraryFileExtension,
    kSparkListFileExtension,
    NSFileTypeForHFSTypeCode(kSparkListFileType),
    nil]];
  if (result == NSOKButton) {
    [self application:NSApp openFile:[[panel filenames] objectAtIndex:0]];
  }
}

#pragma mark -
#pragma mark PlugIn Help Support
- (IBAction)showPlugInHelp:(id)sender {
  [[self plugInHelpWindow] showWindow:nil];
}

- (id)plugInHelpWindow {
  if (!plugInHelpWindow) {
    plugInHelpWindow = [[PlugInHelpController alloc] init];
    [plugInHelpWindow window];
  }
  return plugInHelpWindow;
}

- (void)showPlugInHelpPage:(NSString *)page {
  [[self plugInHelpWindow] setHelpPage:page];
  [self showPlugInHelp:nil];
}

#pragma mark -
#pragma mark Live Update Support
- (IBAction)checkForNewVersion:(id)sender {
  NSString *currVersionNumber = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
  NSDictionary *productVersionDict = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:NSLocalizedStringFromTable(@"UPDATE_FILE_URL",
                                                                                                                               @"Update", @"Url of the update file (.xml or .plist). Do not localize.")]];
  NSString *latestVersionNumber = [productVersionDict valueForKey:@"Spark"];
  if (latestVersionNumber == nil) {
    NSBeginAlertSheet(NSLocalizedStringFromTable(@"UPDATE_CHECKING_ERROR",
                                                 @"Update", @"Check Update Error * Title *"),
                      NSLocalizedStringFromTable(@"OK",
                                                 @"Update", @"Alert default button"),
                      nil, nil, [libraryWindow window],
                      nil, nil, nil, nil,
                      NSLocalizedStringFromTable(@"UPDATE_CHECKING_ERROR_MSG",
                                                 @"Update", @"Check Update Error * Msg * (Replace ChezJD by the web Site URL)"));
    return;
  }
  if([latestVersionNumber isEqualTo:currVersionNumber])
  {
    NSBeginAlertSheet(NSLocalizedStringFromTable(@"SOFTWARE_UP_TO_DATE_NOTIFICATION",
                                                 @"Update", @"When a the user's software is up to date. * Title *"),
                      NSLocalizedStringFromTable(@"OK",
                                                 @"Update", @"Alert default button"),
                      nil, nil, [libraryWindow window],
                      nil, nil, nil, nil,
                      NSLocalizedStringFromTable(@"SOFTWARE_UP_TO_DATE_NOTIFICATION_MSG",
                                                 @"Update", @"When a the user's software is up to date. * Msg *"));
  }
  else {
    id alert = [NSAlert alertWithMessageText:NSLocalizedStringFromTable(@"CONFIRM_GO_TO_UPDATE_PAGE",
                                                                        @"Update", @"New version available")
                               defaultButton:NSLocalizedStringFromTable(@"CONFIRM_GO_TO_UPDATE_PAGE_YES",
                                                                        @"Update", @"New version available * default button *")
                             alternateButton:NSLocalizedStringFromTable(@"CONFIRM_GO_TO_UPDATE_PAGE_CANCEL",
                                                                        @"Update", @"New version available * cancel button *")
                                 otherButton:nil
                   informativeTextWithFormat:NSLocalizedStringFromTable(@"CONFIRM_GO_TO_UPDATE_PAGE_MSG",
                                                                        @"Update", @"New version available * msg *"), latestVersionNumber];
    [alert beginSheetModalForWindow:[libraryWindow window]
                      modalDelegate:self
                     didEndSelector:@selector(checkUpdateAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:nil];
  }
}

- (void)checkUpdateAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(NSDictionary *)plist {
  if(NSAlertDefaultReturn == returnCode) {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedStringFromTable(@"UPDATE_PAGE_URL",
                                                                                           @"Update", @"The url of the update page. Do not localize.")]];
  }
}

#pragma mark -
#pragma mark Restart Functions
+ (void)restartDaemon {
  BOOL running = ([[ServerController sharedController] serverProxy] != nil);
  if (running) {
    [[ServerController sharedController] shutDownServer];
    [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
  }
  [[ServerController sharedController] startServer];
}

+ (void)restartSpark {
  if ([[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]]
                      withAppBundleIdentifier:nil
                                      options:NSWorkspaceLaunchDefault | NSWorkspaceLaunchNewInstance
               additionalEventParamDescriptor:nil
                            launchIdentifiers:nil]) {
    [NSApp terminate:nil];
  } else {
    [NSException raise:NSInternalInconsistencyException format:@"Unable to create new Spark instance"];
  }
}

#pragma mark -
#pragma mark Open File & Sheet Did End
- (BOOL)openList:(NSString *)filename {
  id plist = nil;
  id data = [[NSData alloc] initWithContentsOfFile:filename];
  if (data) {
    plist = [NSPropertyListSerialization propertyListFromData:data 
                                             mutabilityOption:kCFPropertyListMutableContainersAndLeaves
                                                       format:nil
                                             errorDescription:nil];
    [data release];
  }
  if (plist) {
    id import = [[SparkImporter alloc] init];
    [import setSerializedList:plist];
    [NSApp beginSheet: [import window]
       modalForWindow: [libraryWindow window]
        modalDelegate: self
       didEndSelector: @selector(sheetDidEnd:returnCode:context:)
          contextInfo: nil];
    return YES;
  }
  return NO;
}

- (BOOL)openPlugin:(NSString *)filename {
  /* Verifier que le plugin n'est pas d�j� install�.
  � Si install� => Si version sup�rieur, proposer de remplacer, red�marrer server, demander de red�marrer �diteur.
  � Si non install� => Proposer d'installer dans � domaines (Utilisateur et ordinateur).
  */
  id installer = nil;
  CFBundleRef dest = nil;
  CFBundleRef src = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)[NSURL fileURLWithPath:filename]);
  if (!src) {
    DLog(@"Unable to open bundle: %@", filename);
    return NO;
  }
  id identifier = (id)CFBundleGetIdentifier(src);
  
  id plugins = [[[SparkActionLoader sharedLoader] plugIns] objectEnumerator];
  id plugin;
  while (plugin = [plugins nextObject]) {
    if ([identifier isEqualToString:[plugin bundleIdentifier]]) {
      break;
    }
  }
  if (plugin) {
    dest = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)[NSURL fileURLWithPath:[plugin path]]);
  }
  if (dest) {
    UInt32 srcVersion = 0, destVersion = 0;
    srcVersion = CFBundleGetVersionNumber(src);
    destVersion = CFBundleGetVersionNumber(dest);
    
    if (srcVersion <= destVersion) {
      NSBeginAlertSheet(NSLocalizedString(@"MORE_RECENT_PLUGIN_INSTALLED_ALERT",
                                          @"More Recent plugin installed"),
                        NSLocalizedString(@"OK",
                                          @"Alert default button"),
                        nil, nil, [libraryWindow window],
                        nil, nil, nil, nil,
                        NSLocalizedString(@"MORE_RECENT_PLUGIN_INSTALLED_ALERT_MSG",
                                          @"More Recent plugin installed"));
    } else {
      /* Replace plugin */
      installer = [[PluginInstaller alloc] init];
      [installer setSource:src];
      [installer setDestination:dest];
    }
  } else {
    /* Install New Plugin */
    installer = [[PluginInstaller alloc] init];
    [installer setSource:src];
  }
  if (installer) {
    [NSApp beginSheet:[installer window]
       modalForWindow:[libraryWindow window]
        modalDelegate:self
       didEndSelector:@selector(sheetDidEnd:returnCode:context:)
          contextInfo:nil];
  }
  if (src) { CFRelease(src); }
  if (dest) { CFRelease(dest); }
  return YES;
}

- (BOOL)openLibrary:(NSString *)filename {
  SparkLibrary *lib = [[SparkLibrary  alloc] initWithPath:filename];
  if (!lib) {
    return NO;
  }
  
  id alert = [NSAlert alertWithMessageText:NSLocalizedString(@"CHOOSE_IMPORT_LIBRARY_ACTION",
                                                             @"Open Spark Library * Title *")
                             defaultButton:NSLocalizedString(@"CHOOSE_IMPORT_LIBRARY_ACTION_MERGE",
                                                             @"Open Spark Library")
                           alternateButton:NSLocalizedString(@"CHOOSE_IMPORT_LIBRARY_ACTION_RESTORE",
                                                             @"Open Spark Library")
                               otherButton:NSLocalizedString(@"CHOOSE_IMPORT_LIBRARY_ACTION_CANCEL",
                                                             @"Open Spark Library")
                 informativeTextWithFormat:NSLocalizedString(@"CHOOSE_IMPORT_LIBRARY_ACTION_MSG",
                                                             @"Open Spark Library * Msg *"), [filename lastPathComponent]];
  int result = [alert runSheetModalForWindow:[libraryWindow window]];
  if (NSAlertOtherReturn == result) {
    return YES;
  } else if (NSAlertAlternateReturn == result) {
    BOOL running = ([self serverState] == kSparkDaemonStarted);
    if (running) [[ServerController sharedController] shutDownServer];
    [SparkLibrary setDefaultLibrary:lib];
    alert = [NSAlert alertWithMessageText:NSLocalizedString(@"LIBRARY_RESTORED_NOTIFICATION",
                                                            @"Open Spark Library * Title *")
                            defaultButton:NSLocalizedString(@"LIBRARY_RESTORED_NOTIFICATION_RESTART",
                                                            @"Open Spark Library")
                          alternateButton:nil
                              otherButton:nil
                informativeTextWithFormat:@""];
    [alert runSheetModalForWindow:[libraryWindow window]];
    
    if (running) [[ServerController sharedController] startServer];
    [Spark restartSpark];
    return YES;
  } else if (NSAlertDefaultReturn == result) {
    id import = [[SparkImporter alloc] init];
    [import setLibrary:lib];
    [NSApp beginSheet: [import window]
       modalForWindow: [libraryWindow window]
        modalDelegate: self
       didEndSelector: @selector(sheetDidEnd:returnCode:context:)
          contextInfo: nil];
  }
  [lib release];
  return YES;
}

- (void)sheetDidEnd:(id)sheet returnCode:(int)code context:(void *)context {
  [[sheet windowController] autorelease];
  [libraryWindow refresh];
}

#pragma mark -
#pragma mark Windows Delegate
- (void)windowWillClose:(NSNotification *)aNotification {
  [libraryWindow saveWorkspace];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [NSApp terminate:nil];
}

- (BOOL)windowShouldClose:(id)sender {
  return YES;
}

#pragma mark -
#pragma mark Application Delegate

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
  if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath:filename]) {
    if ([[filename pathExtension] isEqualToString:[SparkActionLoader extension]]) {
      if ([self openPlugin:filename])
        return YES;
    } else if ([[filename pathExtension] isEqualToString:kSparkLibraryFileExtension]) {
      if ([self openLibrary:filename])
        return YES;
    }
  } else {
    OSType type = [[[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:NO] fileHFSTypeCode];
    if ([[filename pathExtension] isEqualToString:kSparkListFileExtension] || type == kSparkListFileType) { // Il faudrait aussi verifier le type.
      if ([self openList:filename])
        return YES;
    }
  }
  id error = [NSAlert alertWithMessageText:
    [NSString stringWithFormat:NSLocalizedString(@"INVALID_FILE_ALERT",
                                                 @"Import failed (%@ => filename) * Title *"), [filename lastPathComponent]]
                             defaultButton:NSLocalizedString(@"OK", @"Alert default button") 
                           alternateButton:nil
                               otherButton:nil
                 informativeTextWithFormat:NSLocalizedString(@"INVALID_FILE_ALERT_MSG",
                                                             @"Open failed * Msg *")];
  [error beginSheetModalForWindow:[libraryWindow window]
                    modalDelegate:nil
                   didEndSelector:nil
                      contextInfo:nil];
  return NO;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  [SparkDefaultLibrary() synchronize];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
  return YES;
}

#pragma mark -
#pragma mark About Plugins Menu

- (void)createAboutMenu {
  while ([aboutMenu numberOfItems]) {
    [aboutMenu removeItemAtIndex:0];
  }
  id desc = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)];
  id plugins = [[[SparkActionLoader sharedLoader] plugIns] sortedArrayUsingDescriptors:[NSArray arrayWithObject:desc]];
  [desc release];
  plugins = [plugins objectEnumerator];
  id plugin;
  while (plugin = [plugins nextObject]) {
    id menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"ABOUT_PLUGIN_MENU_ITEM", @"About Plugin (%@ => Plugin name)"), [plugin name]]
                                             action:@selector(aboutPlugin:) keyEquivalent:@""];
    [menuItem setImage:[plugin icon]];
    [menuItem setRepresentedObject:plugin];
    [aboutMenu addItem:menuItem];
    [menuItem release];
  }
}

- (IBAction)aboutPlugin:(id)sender {
  id plugin = [sender representedObject];
  id opts = [NSMutableDictionary dictionary];
  
  [opts setObject:[NSString stringWithFormat:NSLocalizedString(@"ABOUT_PLUGIN_BOX_TITLE", @"About Plugin (%@ => Plugin name)"), [plugin name]] forKey:@"ApplicationName"];
  NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[plugin path]];
  [icon setSize:NSMakeSize(64, 64)];
  [opts setObject:icon forKey:@"ApplicationIcon"];
  id bundle = [NSBundle bundleWithPath:[plugin path]];
  
  id value = nil;
  id credits = nil;
  if ((credits = [bundle pathForResource:@"Credits" ofType:@"html"]) ||
      (credits = [bundle pathForResource:@"Credits" ofType:@"rtf"]) ||
      (credits = [bundle pathForResource:@"Credits" ofType:@"rtfd"])) {
    value = [[NSAttributedString alloc] initWithURL:[NSURL fileURLWithPath:credits] documentAttributes:nil];
    [opts setObject:value forKey:@"Credits"];
    [value release];
  } else {
    [opts setObject:@"" forKey:@"Credits"];
  }
  
  value = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
  [opts setObject:(value) ? value : @"" forKey:@"Version"];
  value = [bundle objectForInfoDictionaryKey:@"NSHumanReadableCopyright"];
  [opts setObject:(value) ? value : @"" forKey:@"Copyright"];
  value = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  [opts setObject:(value) ? value : @"" forKey:@"ApplicationVersion"];
  [NSApp orderFrontStandardAboutPanelWithOptions:opts];
}

- (void)sparkDidChangePlugIn:(NSNotification *)aNotification {
  [self createAboutMenu];
}

#pragma mark -
#pragma mark Debug Menu

#if defined (DEBUG)
- (void)createDebugMenu {
  id debugMenu = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
  id menu = [[NSMenu alloc] initWithTitle:@"Debug"];
  [menu addItemWithTitle:@"Install" action:@selector(openInstaller:) keyEquivalent:@""];
  [menu addItemWithTitle:@"Importer" action:@selector(openImporter:) keyEquivalent:@""];
  [menu addItemWithTitle:@"Action Chooser" action:@selector(openActionChooser:) keyEquivalent:@""];
  [menu addItemWithTitle:@"Application/Action Editor" action:@selector(openAppActionEditor:) keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Clean Library" action:@selector(cleanLibrary:) keyEquivalent:@""];
  [debugMenu setSubmenu:menu];
  [menu release];
  [[NSApp mainMenu] insertItem:debugMenu atIndex:[[NSApp mainMenu] numberOfItems] -1];
  [debugMenu release];
}

- (IBAction)openAppActionEditor:(id)sender {
  if (libraryWindow) {
    id appActionSheet = [[AppActionEditor alloc] init];
    [NSApp beginSheet: [appActionSheet window]
       modalForWindow: [libraryWindow window]
        modalDelegate: self
       didEndSelector: @selector(sheetDidEnd:returnCode:context:)
          contextInfo: nil];
  }
}

- (IBAction)openActionChooser:(id)sender {
  if (libraryWindow) {
    id actionChooser = [[ChoosePanel alloc] initWithObjectType:kSparkAction];
    [NSApp beginSheet: [actionChooser window]
       modalForWindow: [libraryWindow window]
        modalDelegate: self
       didEndSelector: @selector(sheetDidEnd:returnCode:context:)
          contextInfo: nil];
  }
}

- (IBAction)openImporter:(id)sender {
  if (libraryWindow) {
    id panel = [[SparkImporter alloc] init];
    id lib = [[SparkLibrary alloc] initWithPath:[SparkDefaultLibrary() file]];
    [panel setLibrary:lib];
    [lib release];
    [NSApp beginSheet: [panel window]
       modalForWindow: [libraryWindow window]
        modalDelegate: self
       didEndSelector: @selector(sheetDidEnd:returnCode:context:)
          contextInfo: nil];
  }
}

- (IBAction)openInstaller:(id)sender {
  if (libraryWindow) {
    id panel = [[PluginInstaller alloc] init];
    [NSApp beginSheet: [panel window]
       modalForWindow: [libraryWindow window]
        modalDelegate: self
       didEndSelector: @selector(sheetDidEnd:returnCode:context:)
          contextInfo: nil];
  }
}

- (IBAction)cleanLibrary:(id)sender {
  [SparkDefaultLibrary() flush];
}

#endif

@end
