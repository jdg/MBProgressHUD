//
//  HudDemoViewController.m
//  HudDemo
//
//  Created by Matej Bukovinski on 30.9.09.
//  Copyright bukovinski.com 2009. All rights reserved.
//

#import "HudDemoViewController.h"
#import <unistd.h>

@implementation HudDemoViewController

#pragma mark -
#pragma mark Lifecycle methods

- (void)viewDidLoad {
	UIView *content = [[self.view subviews] objectAtIndex:0];
	((UIScrollView *)self.view).contentSize = content.bounds.size;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // No autoroation support when adding the HUD to a window!
    // In that case you need to explicitly transform the HUD if you need a rotated version (i.g.,
    // self.transform = CGAffineTransformMakeRotation(PI / 2); )
    return YES;	
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	UIView *content = [[self.view subviews] objectAtIndex:0];
	((UIScrollView *)self.view).contentSize = content.bounds.size;
}

- (void)dealloc {
    [super dealloc];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)showSimple:(id)sender {
    // The hud will dispable all input on the view (use the higest view possible in the view hierarchy)
    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
	
	//HUD.graceTime = 0.5;
	//HUD.minShowTime = 5.0;
	
    // Add HUD to screen
    [self.navigationController.view addSubview:HUD];
	
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
	
    // Show the HUD while the provided method executes in a new thread
    [HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showWithLabel:(id)sender {
	// The hud will dispable all input on the view (use the higest view possible in the view hierarchy)
    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
	
    // Add HUD to screen
    [self.navigationController.view addSubview:HUD];
	
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
	
    HUD.labelText = @"Loading";
	
    // Show the HUD while the provided method executes in a new thread
    [HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showWithDetailsLabel:(id)sender {
    // The hud will dispable all input on the view (use the higest view possible in the view hierarchy)
    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
	
    // Add HUD to screen
    [self.navigationController.view addSubview:HUD];
	
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
	
    HUD.labelText = @"Loading";
    HUD.detailsLabelText = @"updating data";
	
    // Show the HUD while the provided method executes in a new thread
    [HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showWithLabelDeterminate:(id)sender {
	// The hud will dispable all input on the view (use the higest view possible in the view hierarchy)
    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
	
    // Set determinate mode
    HUD.mode = MBProgressHUDModeDeterminate;
	
    // Add HUD to screen
    [self.navigationController.view addSubview:HUD];
	
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
	
    HUD.labelText = @"Loading";
	
    // Show the HUD while the provided method executes in a new thread
    [HUD showWhileExecuting:@selector(myProgressTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showWithCustomView:(id)sender {
	// The hud will dispable all input on the view (use the higest view possible in the view hierarchy)
    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
	
	// The sample image is based on the work by www.pixelpressicons.com, http://creativecommons.org/licenses/by/2.5/ca/
	// Make the customViews 37 by 37 pixels for best results (those are the bounds of the build-in progress indicators)
	HUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]] autorelease];
	
    // Set custom view mode
    HUD.mode = MBProgressHUDModeCustomView;
	
	// Add HUD to screen
    [self.navigationController.view addSubview:HUD];
	
	// Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
	
    HUD.labelText = @"Completed";
	
	// This would only show the completed text with no visible custom view
	// HUD.customView = [[UIView alloc] initWithFrame:CGRectZero];
	
	// Show the HUD while the provided method executes in a new thread
    [HUD showWhileExecuting:@selector(myProgressTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showWithLabelMixed:(id)sender {
	// The hud will dispable all input on the view (use the higest view possible in the view hierarchy)
    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
	
    // Add HUD to screen
    [self.navigationController.view addSubview:HUD];
	
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
	
    HUD.labelText = @"Connecting";
	
    // Show the HUD while the provided method executes in a new thread
    [HUD showWhileExecuting:@selector(myMixedTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showUsingBlocks:(id)sender {
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		// Show the HUD in the main tread 
		dispatch_async(dispatch_get_main_queue(), ^{
			// No need to hod onto (retain)
			MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
			hud.labelText = @"Loading";
		});
		
		// Do a taks in the background
		[self myTask];
		
		// Hide the HUD in the main tread 
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
		});
	});
}

- (IBAction)showOnWindow:(id)sender {
	// The hud will dispable all input on the view
    HUD = [[MBProgressHUD alloc] initWithView:self.view.window];
	
    // Add HUD to screen
    [self.view.window addSubview:HUD];
	
    // Regisete for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
	
    HUD.labelText = @"Loading";
	
    // Show the HUD while the provided method executes in a new thread
    [HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
}

#pragma mark -
#pragma mark Execution code

- (void)myTask {
    // Do something usefull in here instead of sleeping ...
    sleep(3);
    // Labels can be changed during the execution
    //HUD.detailsLabelText = @"Something";
    //sleep(3);
}

- (void)myProgressTask {
    // This just increases the progress indicator in a loop
    float progress = 0.0f;
    while (progress < 1.0f) {
        progress += 0.01f;
        HUD.progress = progress;
        usleep(50000);
    }
}

- (void)myMixedTask {
    // Indeterminate mode
    sleep(2);
    // Switch to determinate mode
    HUD.mode = MBProgressHUDModeDeterminate;
    HUD.labelText = @"Downloading";
    float progress = 0.0f;
    while (progress < 1.0f)
    {
        progress += 0.01f;
        HUD.progress = progress;
        usleep(50000);
    }
    // Back to indeterminate mode
    HUD.mode = MBProgressHUDModeIndeterminate;
    HUD.labelText = @"Cleaning up";
    sleep(2);
	// The sample image is based on the work by www.pixelpressicons.com, http://creativecommons.org/licenses/by/2.5/ca/
	// Make the customViews 37 by 37 pixels for best results (those are the bounds of the build-in progress indicators)
	HUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]] autorelease];
	HUD.mode = MBProgressHUDModeCustomView;
	HUD.labelText = @"Completed";
	sleep(2);
}

#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden {
    // Remove HUD from screen when the HUD was hidded
    [HUD removeFromSuperview];
    [HUD release];
}

@end
