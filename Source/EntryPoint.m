@import AppKit;

#include "AppDelegate.h"
#include "MainViewController.h"

#include "AppDelegate.m"
#include "MainViewController.m"

int main(void) {
	[NSApplication sharedApplication];
	AppDelegate *appDelegate = [[AppDelegate alloc] init];
	NSApp.delegate = appDelegate;
	[NSApp run];
}
