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
	@[@[[MBExample exampleWithTitle:@"Indeterminate mode" selector:@selector(simple)],
		[MBExample exampleWithTitle:@"With label" selector:@selector(simple)],
		[MBExample exampleWithTitle:@"With details label" selector:@selector(simple)],
		[MBExample exampleWithTitle:@"On window" selector:@selector(simple)]],
	  @[[MBExample exampleWithTitle:@"Determinate mode" selector:@selector(simple)],
		[MBExample exampleWithTitle:@"Annular determinate mode" selector:@selector(simple)],
		[MBExample exampleWithTitle:@"Bar determinate mode" selector:@selector(simple)]],
	  @[[MBExample exampleWithTitle:@"Custom view" selector:@selector(simple)],
		[MBExample exampleWithTitle:@"Text only" selector:@selector(simple)],
		[MBExample exampleWithTitle:@"Mode switching" selector:@selector(simple)]],
	  @[[MBExample exampleWithTitle:@"NSURLConnection" selector:@selector(simple)]],
	  @[[MBExample exampleWithTitle:@"Dim background" selector:@selector(simple)],
		[MBExample exampleWithTitle:@"Colored" selector:@selector(simple)]]
	  ];
}

#pragma mark - Examples

- (void)simple {
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
	[hud hideAnimated:YES afterDelay:3.f];
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
	cell.textLabel.textColor = [UIColor colorWithRed:0.393f green:0.467f blue:0.572f alpha:1.f];
	cell.textLabel.textAlignment = NSTextAlignmentCenter;
	cell.selectedBackgroundView = [UIView new];
	cell.selectedBackgroundView.backgroundColor = [cell.textLabel.textColor colorWithAlphaComponent:0.5];
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
