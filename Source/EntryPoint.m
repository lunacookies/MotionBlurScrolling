@import AppKit;
@import Metal;
@import QuartzCore;
@import simd;

#include "AppDelegate.h"
#include "MainViewController.h"
#include "MetalScrollView.h"

#include "AppDelegate.m"
#include "MainViewController.m"
#include "MetalScrollView.m"

int main(void) {
	setenv("MTL_SHADER_VALIDATION", "1", 1);
	setenv("MTL_DEBUG_LAYER", "1", 1);
	setenv("MTL_DEBUG_LAYER_WARNING_MODE", "nslog", 1);

	[NSApplication sharedApplication];
	AppDelegate *appDelegate = [[AppDelegate alloc] init];
	NSApp.delegate = appDelegate;
	[NSApp run];
}
