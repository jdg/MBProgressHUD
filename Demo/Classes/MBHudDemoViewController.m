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
		[MBExample exampleWithTitle:@"With label" selector:@selector(indeterminateExample)],
		[MBExample exampleWithTitle:@"With details label" selector:@selector(indeterminateExample)],
		[MBExample exampleWithTitle:@"On window" selector:@selector(indeterminateExample)]],
	  @[[MBExample exampleWithTitle:@"Determinate mode" selector:@selector(indeterminateExample)],
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

#pragma mark - Tasks

- (void)doSomeWork {
	// Simulate by just waiting.
	sleep(3.);
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
