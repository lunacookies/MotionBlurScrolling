@import AppKit;
@import QuartzCore;
@import simd;

#include "AppDelegate.h"
#include "MainViewController.h"
#include "MetalScrollView.h"

#include "AppDelegate.m"
#include "MainViewController.m"
#include "MetalScrollView.m"

int main(void) {
	[NSApplication sharedApplication];
	AppDelegate *appDelegate = [[AppDelegate alloc] init];
	NSApp.delegate = appDelegate;
	[NSApp run];
}
