//
//  MBHudDemoViewController.m
//  HudDemo
//
//  Created by Matej Bukovinski on 30.9.09.
//  Copyright bukovinski.com 2009-2015. All rights reserved.
//

#import "MBHudDemoViewController.h"
#import "MBProgressHUD.h"


@interface MBExample : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) SEL selector;

@end


@implementation MBExample

+ (instancetype)exampleWithTitle:(NSString *)title selector:(SEL)selector {
	MBExample *example = [[self class] new];
	example.title = title;
	example.selector = selector;
	return example;
}

@end


@interface MBHudDemoViewController ()

@property (nonatomic, strong) NSArray<NSArray<MBExample *> *> *examples;

@end


@implementation MBHudDemoViewController

#pragma mark - Lifecycle

- (void)awakeFromNib {
	[super awakeFromNib];
	self.examples =
	@[@[[MBExample exampleWithTitle:@"Indeterminate mode" selector:@selector(indeterminateExample)],
		[MBExample exampleWithTitle:@"With label" selector:@selector(labelExample)],
		[MBExample exampleWithTitle:@"With details label" selector:@selector(detailsLabelExample)],
		[MBExample exampleWithTitle:@"On window" selector:@selector(indeterminateExample)]],
	  @[[MBExample exampleWithTitle:@"Determinate mode" selector:@selector(determinateExample)],
		[MBExample exampleWithTitle:@"Annular determinate mode" selector:@selector(indeterminateExample)],
		[MBExample exampleWithTitle:@"Bar determinate mode" selector:@selector(indeterminateExample)]],
	  @[[MBExample exampleWithTitle:@"Custom view" selector:@selector(indeterminateExample)],
		[MBExample exampleWithTitle:@"Text only" selector:@selector(indeterminateExample)],
		[MBExample exampleWithTitle:@"Mode switching" selector:@selector(indeterminateExample)]],
	  @[[MBExample exampleWithTitle:@"NSURLConnection" selector:@selector(indeterminateExample)]],
	  @[[MBExample exampleWithTitle:@"Dim background" selector:@selector(indeterminateExample)],
		[MBExample exampleWithTitle:@"Colored" selector:@selector(indeterminateExample)]]
	  ];
}

#pragma mark - Examples

- (void)indeterminateExample {
	// Show the HUD on the root view (self.view is a scrollable table view and thus not suitable,
	// as the HUD would move with the content as we scroll).
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];

	// Fire off an asynchronous task, giving UIKit the opportunity to redraw wit the HUD added to the
	// view hierarchy.
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{

		// Do something useful in the background
		[self doSomeWork];

		// IMPORTANT - Dispatch back to the main thread. Always access UI
		// classes (including MBProgressHUD) on the main thread.
		dispatch_async(dispatch_get_main_queue(), ^{
			[hud hideAnimated:YES];
		});
	});
}

- (void)labelExample {
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];

	// Set the label text.
	hud.label.text = NSLocalizedString(@"Loading...", @"HUD title");
	// You can also adjust other label properties if needed.
	// hud.label.font = [UIFont italicSystemFontOfSize:16.f];

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		[self doSomeWork];
		dispatch_async(dispatch_get_main_queue(), ^{
			[hud hideAnimated:YES];
		});
	});
}

- (void)detailsLabelExample {
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];

	// Set the label text.
	hud.label.text = NSLocalizedString(@"Loading...", @"HUD title");
	// Set the details label text. Let's make it multiline this time.
	hud.detailsLabel.text = NSLocalizedString(@"Parsing data\n(1/1)", @"HUD title");

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		[self doSomeWork];
		dispatch_async(dispatch_get_main_queue(), ^{
			[hud hideAnimated:YES];
		});
	});
}

- (void)windowExample {
	// Covers the entire screen. Similar to using the root view controller view.
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view.window animated:YES];
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		[self doSomeWork];
		dispatch_async(dispatch_get_main_queue(), ^{
			[hud hideAnimated:YES];
		});
	});
}

- (void)determinateExample {
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];

	// Set the determinate mode to show task porgress.
	hud.mode = MBProgressHUDModeDeterminate;
	hud.label.text = NSLocalizedString(@"Loading...", @"HUD title");

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		// Do something useful in the background and update the HUD periodically.
		[self doSomeWorkWithProgress];
		dispatch_async(dispatch_get_main_queue(), ^{
			[hud hideAnimated:YES];
		});
	});
}

#pragma mark - Tasks

- (void)doSomeWork {
	// Simulate by just waiting.
	sleep(3.);
}

- (void)doSomeWorkWithProgress {
	// This just increases the progress indicator in a loop.
	float progress = 0.0f;
	while (progress < 1.0f) {
		progress += 0.01f;
		dispatch_async(dispatch_get_main_queue(), ^{
			// Instead we could have also passed a reference to the HUD
			// to the HUD to myProgressTask as a method parameter.
			[MBProgressHUD HUDForView:self.navigationController.view].progress = progress;
		});
		usleep(50000);
	}
}

#pragma mark - UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.examples.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.examples[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	MBExample *example = self.examples[indexPath.section][indexPath.row];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MBExampleCell" forIndexPath:indexPath];
	cell.textLabel.text = example.title;
	cell.textLabel.textColor = self.view.tintColor;
	cell.textLabel.textAlignment = NSTextAlignmentCenter;
	cell.selectedBackgroundView = [UIView new];
	cell.selectedBackgroundView.backgroundColor = [cell.textLabel.textColor colorWithAlphaComponent:0.1f];
	return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	MBExample *example = self.examples[indexPath.section][indexPath.row];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[self performSelector:example.selector];
#pragma clang diagnostic pop

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
	});
}

@end
