//
//  HudTests.m
//  HudTests
//
//  Created by Matej Bukovinski on 8. 02. 15.
//  Copyright (c) 2015 Matej Bukovinski. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "MBProgressHUD.h"


@interface HudTests : XCTestCase

@property (nonatomic, strong) MBProgressHUD *hud;
@property (nonatomic, strong) UIView *view;

@end

@implementation HudTests

- (void)setUp {
    [super setUp];

    self.view = [[UIView alloc] init];
    self.view.bounds = [[UIScreen mainScreen] bounds];
    self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
}

- (void)tearDown {
    self.hud = nil;
    self.view = nil;

    [super tearDown];
}

- (void)testThatHUDExists {
    XCTAssertNotNil(self.hud, @"Should be able to create a new HUD instance");
}

@end
