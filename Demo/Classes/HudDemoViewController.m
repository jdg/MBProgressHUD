//
//  HudDemoViewController.m
//  HudDemo
//
//  Created by Matej Bukovinski on 30.9.09.
//  Copyright bukovinski.com 2009. All rights reserved.
//

#import "HudDemoViewController.h"

@implementation HudDemoViewController

- (IBAction) showSimple:(id)sender {
	
	// Should be initialized with the windows frame so the HUD disables all user input by covering the entire screen
	UIWindow *window = [UIApplication sharedApplication].keyWindow;
	HUD = [[MBProgressHUD alloc] initWithWindow:window];
	
	// Add HUD to screen
	[window addSubview:HUD];
	
	// Regisete for HUD callbacks so we can remove it from the window at the right time
	HUD.delegate = self;
	
	// Show the HUD while the provided method executes in a new thread
	[HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
	
}

- (IBAction) showWithLabel:(id)sender {
	
	// Should be initialized with the windows frame so the HUD disables all user input by covering the entire screen
	UIWindow *window = [UIApplication sharedApplication].keyWindow;
	HUD = [[MBProgressHUD alloc] initWithWindow:window];
	
	// Add HUD to screen
	[window addSubview:HUD];
	
	// Regisete for HUD callbacks so we can remove it from the window at the right time
	HUD.delegate = self;
	
	HUD.labelText = @"Loading";
	
	// Show the HUD while the provided method executes in a new thread
	[HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction) showWithDetailsLabel:(id)sender {
	
	// Should be initialized with the windows frame so the HUD disables all user input by covering the entire screen
	UIWindow *window = [UIApplication sharedApplication].keyWindow;
	HUD = [[MBProgressHUD alloc] initWithWindow:window];
	
	// Add HUD to screen
	[window addSubview:HUD];
	
	// Regisete for HUD callbacks so we can remove it from the window at the right time
	HUD.delegate = self;
	
	HUD.labelText = @"Loading";
	HUD.detailsLabelText = @"updating data";
	
	// Show the HUD while the provided method executes in a new thread
	[HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
	
}

- (IBAction) showWithLabelDeterminate:(id)sender {
	
	// Should be initialized with the windows frame so the HUD disables all user input by covering the entire screen
	UIWindow *window = [UIApplication sharedApplication].keyWindow;
	HUD = [[MBProgressHUD alloc] initWithWindow:window];
	
	// Set determinate mode
	HUD.mode = MBProgressHUDModeDeterminate;
	
	// Add HUD to screen
	[window addSubview:HUD];
	
	// Regisete for HUD callbacks so we can remove it from the window at the right time
	HUD.delegate = self;
	
	HUD.labelText = @"Loading";
	
	// Show the HUD while the provided method executes in a new thread
	[HUD showWhileExecuting:@selector(myProgressTask) onTarget:self withObject:nil animated:YES];
	
}

- (IBAction) showWithLabelMixed:(id)sender {
	
	// Should be initialized with the windows frame so the HUD disables all user input by covering the entire screen
	UIWindow *window = [UIApplication sharedApplication].keyWindow;
	HUD = [[MBProgressHUD alloc] initWithWindow:[UIApplication sharedApplication].keyWindow];
	
	// Add HUD to screen
	[window addSubview:HUD];
	
	// Regisete for HUD callbacks so we can remove it from the window at the right time
	HUD.delegate = self;
	
	HUD.labelText = @"Connecting";
	
	// Show the HUD while the provided method executes in a new thread
	[HUD showWhileExecuting:@selector(myMixedTask) onTarget:self withObject:nil animated:YES];
	
}

- (void) myTask {
	// Do something usefull in here instead of sleeping ...
	sleep(1);
	// Labels can be changed during the execution
	//HUD.detailsLabelText = @"Something";
	//sleep(3);
}

- (void) myProgressTask {
	// This just increases the progress indicator in a loop
	float progress = 0.0f;
	while (progress < 1.0f) {
		progress += 0.01f;
		HUD.progress = progress;
		usleep(50000);
	}
}

- (void) myMixedTask {
	// Indeterminate mode
	sleep(2);
	// Switch to determinate mode
	HUD.mode = MBProgressHUDModeDeterminate;
	HUD.labelText = @"Downloading";
	float progress = 0.0f;
	while (progress < 1.0f) {
		progress += 0.01f;
		HUD.progress = progress;
		usleep(50000);
	}
	// Back to indeterminate mode
	HUD.mode = MBProgressHUDModeIndeterminate;
	HUD.labelText = @"Cleaning up";
	sleep(2);
}

- (void)hudWasHidden {
	// Remove HUD from screen when the HUD was hidded
	[HUD removeFromSuperview];
	[HUD release];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// No autoroation support for the HUD since we aren't using a ViewController but rather adding
	// the HUD view as a direct subview of the window. 
	// You need to explicitly transform the HUD if you need a rotated version (i.g.,
	// self.transform = CGAffineTransformMakeRotation(PI / 2); )
	return NO;	
}


- (void)dealloc {
    [super dealloc];
}

@end
