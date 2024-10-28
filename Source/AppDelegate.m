@implementation AppDelegate {
	NSWindow *window;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	NSString *displayName = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];

	NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];

	{
		NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:displayName action:nil keyEquivalent:@""];
		[mainMenu addItem:appMenuItem];

		NSMenu *appMenu = [[NSMenu alloc] initWithTitle:displayName];
		appMenuItem.submenu = appMenu;

		NSString *aboutMenuItemTitle = [NSString stringWithFormat:@"About %@", displayName];
		NSMenuItem *aboutMenuItem = [[NSMenuItem alloc] initWithTitle:aboutMenuItemTitle
		                                                       action:@selector(orderFrontStandardAboutPanel:)
		                                                keyEquivalent:@""];
		[appMenu addItem:aboutMenuItem];

		[appMenu addItem:[NSMenuItem separatorItem]];

		NSMenuItem *preferencesMenuItem = [[NSMenuItem alloc] initWithTitle:@"Preferences…"
		                                                             action:nil
		                                                      keyEquivalent:@","];
		[appMenu addItem:preferencesMenuItem];

		[appMenu addItem:[NSMenuItem separatorItem]];

		NSMenuItem *servicesMenuItem = [[NSMenuItem alloc] initWithTitle:@"Services" action:nil keyEquivalent:@""];
		[appMenu addItem:servicesMenuItem];

		NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:@"Services"];
		servicesMenuItem.submenu = servicesMenu;
		NSApp.servicesMenu = servicesMenu;

		[appMenu addItem:[NSMenuItem separatorItem]];

		NSString *hideMenuItemTitle = [NSString stringWithFormat:@"Hide %@", displayName];
		NSMenuItem *hideMenuItem = [[NSMenuItem alloc] initWithTitle:hideMenuItemTitle
		                                                      action:@selector(hide:)
		                                               keyEquivalent:@"h"];
		[appMenu addItem:hideMenuItem];

		NSMenuItem *hideOthersMenuItem = [[NSMenuItem alloc] initWithTitle:@"Hide Others"
		                                                            action:@selector(hideOtherApplications:)
		                                                     keyEquivalent:@"h"];
		hideOthersMenuItem.keyEquivalentModifierMask |= NSEventModifierFlagOption;
		[appMenu addItem:hideOthersMenuItem];

		NSMenuItem *showAllMenuItem = [[NSMenuItem alloc] initWithTitle:@"Show All"
		                                                         action:@selector(unhideAllApplications:)
		                                                  keyEquivalent:@""];
		[appMenu addItem:showAllMenuItem];

		[appMenu addItem:[NSMenuItem separatorItem]];

		NSString *quitMenuItemTitle = [NSString stringWithFormat:@"Quit %@", displayName];
		NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:quitMenuItemTitle
		                                                      action:@selector(terminate:)
		                                               keyEquivalent:@"q"];
		[appMenu addItem:quitMenuItem];
	}

	{
		NSMenuItem *windowMenuItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
		[mainMenu addItem:windowMenuItem];

		NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
		windowMenuItem.submenu = windowMenu;

		NSMenuItem *closeMenuItem = [[NSMenuItem alloc] initWithTitle:@"Close"
		                                                       action:@selector(performClose:)
		                                                keyEquivalent:@"w"];
		[windowMenu addItem:closeMenuItem];

		NSMenuItem *minimizeMenuItem = [[NSMenuItem alloc] initWithTitle:@"Minimize"
		                                                          action:@selector(performMiniaturize:)
		                                                   keyEquivalent:@"m"];
		[windowMenu addItem:minimizeMenuItem];

		NSMenuItem *zoomMenuItem = [[NSMenuItem alloc] initWithTitle:@"Zoom"
		                                                      action:@selector(performZoom:)
		                                               keyEquivalent:@""];
		[windowMenu addItem:zoomMenuItem];

		[windowMenu addItem:[NSMenuItem separatorItem]];

		NSMenuItem *bringAllToFrontMenuItem = [[NSMenuItem alloc] initWithTitle:@"Bring All to Front"
		                                                                 action:@selector(arrangeInFront:)
		                                                          keyEquivalent:@""];
		[windowMenu addItem:bringAllToFrontMenuItem];

		NSMenuItem *enterFullScreenMenuItem = [[NSMenuItem alloc] initWithTitle:@"Enter Full Screen"
		                                                                 action:@selector(toggleFullScreen:)
		                                                          keyEquivalent:@"f"];
		enterFullScreenMenuItem.keyEquivalentModifierMask |= NSEventModifierFlagControl;
		[windowMenu addItem:enterFullScreenMenuItem];

		NSApp.windowsMenu = windowMenu;
	}

	NSApp.mainMenu = mainMenu;

	window = [NSWindow windowWithContentViewController:[[MainViewController alloc] init]];
	[window makeKeyAndOrderFront:nil];
	[NSApp activate];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}

@end
