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
#pragma mark Constants

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
    [self.navigationController.view addSubview:HUD];
	
    // Regiser for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
	
    // Show the HUD while the provided method executes in a new thread
    [HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showWithLabel:(id)sender {

    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
	[self.navigationController.view addSubview:HUD];
	
    HUD.delegate = self;
    HUD.labelText = @"Loading";
	
    [HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showWithDetailsLabel:(id)sender {
	
    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
    [self.navigationController.view addSubview:HUD];
	
    HUD.delegate = self;
    HUD.labelText = @"Loading";
    HUD.detailsLabelText = @"updating data";
	
    [HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showWithLabelDeterminate:(id)sender {

    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
	[self.navigationController.view addSubview:HUD];
	
    // Set determinate mode
    HUD.mode = MBProgressHUDModeDeterminate;
    
	HUD.delegate = self;
    HUD.labelText = @"Loading";
	
	// myProgressTask uses the HUD instance to update progress
    [HUD showWhileExecuting:@selector(myProgressTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showWithCustomView:(id)sender {

    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
	[self.navigationController.view addSubview:HUD];
	
	// The sample image is based on the work by http://www.pixelpressicons.com, http://creativecommons.org/licenses/by/2.5/ca/
	// Make the customViews 37 by 37 pixels for best results (those are the bounds of the build-in progress indicators)
	HUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]] autorelease];
	
    // Set custom view mode
    HUD.mode = MBProgressHUDModeCustomView;
	
    HUD.delegate = self;
    HUD.labelText = @"Completed";
	
    [HUD show:YES];
	[HUD hide:YES afterDelay:3];
}

- (IBAction)showWithLabelMixed:(id)sender {

    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
	[self.navigationController.view addSubview:HUD];
	
    HUD.delegate = self;
    HUD.labelText = @"Connecting";
	
    [HUD showWhileExecuting:@selector(myMixedTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showUsingBlocks:(id)sender {
#ifdef __BLOCKS__
	// No need to retain (just a local variable)
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
	hud.labelText = @"Loading";
	
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		// Do a taks in the background
		[self myTask];
		// Hide the HUD in the main tread 
		dispatch_async(dispatch_get_main_queue(), ^{
			[MBProgressHUD hideHUDForView:self.navigationController.view animated:YES];
		});
	});
#endif
}

- (IBAction)showOnWindow:(id)sender {
	// The hud will dispable all input on the window
    HUD = [[MBProgressHUD alloc] initWithView:self.view.window];
    [self.view.window addSubview:HUD];
	
    HUD.delegate = self;
    HUD.labelText = @"Loading";
	
    [HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
}

- (IBAction)showURL:(id)sender {
	NSURL *URL = [NSURL URLWithString:@"https://github.com/matej/MBProgressHUD/zipball/master"];
	NSURLRequest *request = [NSURLRequest requestWithURL:URL];
	
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	[connection start];
	[connection release];
	
	HUD = [[MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES] retain];
}


- (IBAction)showWithGradient:(id)sender {
	
    HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
	[self.navigationController.view addSubview:HUD];
	
	HUD.dimBackground = YES;
	
	// Regiser for HUD callbacks so we can remove it from the window at the right time
    HUD.delegate = self;
	
    // Show the HUD while the provided method executes in a new thread
    [HUD showWhileExecuting:@selector(myTask) onTarget:self withObject:nil animated:YES];
}

#pragma mark -
#pragma mark Execution code

- (void)myTask {
    // Do something usefull in here instead of sleeping ...
    sleep(3);
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
    HUD.labelText = @"Progress";
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
#pragma mark NSURLConnectionDelegete

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	expectedLength = [response expectedContentLength];
	currentLength = 0;
	HUD.mode = MBProgressHUDModeDeterminate;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	currentLength += [data length];
	HUD.progress = currentLength / (float)expectedLength;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	HUD.customView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]] autorelease];
    HUD.mode = MBProgressHUDModeCustomView;
	[HUD hide:YES afterDelay:2];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[HUD hide:YES];
}

#pragma mark -
#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidded
    [HUD removeFromSuperview];
    [HUD release];
	HUD = nil;
}

@end
