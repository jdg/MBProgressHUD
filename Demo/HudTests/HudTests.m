//
//  HudTests.m
//  HudTests
//
//  Created by Matej Bukovinski on 31. 01. 16.
//  Copyright © 2016 Matej Bukovinski. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MBProgressHUD.h"


#define weakify(var) __weak typeof(var) weak_##var = var;

#define strongify(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong typeof(var) var = weak_##var; \
_Pragma("clang diagnostic pop")

#define MBTestHUDIsVisible(hud, rootView) \
do { \
XCTAssertEqualObjects(hud.superview, rootView, @"The hud should be added to the view."); \
XCTAssertEqual(hud.alpha, 1.f, @"The HUD should be visible."); \
XCTAssertFalse(hud.hidden, @"The HUD should be visible."); \
XCTAssertEqual(hud.bezelView.alpha, 1.f, @"The HUD should be visible."); \
} while (0)

#define MBTestHUDIsHidenAndRemoved(hud, rootView) \
do { \
XCTAssertFalse([rootView.subviews containsObject:hud], @"The HUD should not be part of the view hierarchy."); \
XCTAssertEqual(hud.alpha, 0.f, @"The hud should be faded out."); \
XCTAssertNil(hud.superview, @"The HUD should not have a superview."); \
} while (0)

@interface HudTests : XCTestCase <MBProgressHUDDelegate>

@property (nonatomic) XCTestExpectation *hideExpectation;
@property (nonatomic, copy) dispatch_block_t hideChecks;

@end


@implementation HudTests

#pragma mark - Convenience

- (void)testNonAnimatedConvenienceHUDPresentation {
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIView *rootView = rootViewController.view;

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:rootView animated:NO];

    XCTAssertNotNil(hud, @"A HUD should be created.");
    MBTestHUDIsVisible(hud, rootView);

    XCTAssertEqual(hud.bezelView.alpha, 1.f, @"The HUD should be visible.");
    XCTAssertFalse([hud.bezelView.layer.animationKeys containsObject:@"opacity"], @"The opacity should NOT be animated.");

    XCTAssertEqualObjects([MBProgressHUD HUDForView:rootView], hud, @"The HUD should be found via the convenience operation.");

    XCTAssertTrue([MBProgressHUD hideHUDForView:rootView animated:NO], @"The HUD should be found and removed.");

    MBTestHUDIsHidenAndRemoved(hud, rootView);

    XCTAssertFalse([MBProgressHUD hideHUDForView:rootView animated:NO], @"A subsequent HUD hide operation should fail.");
}

- (void)testAnimatedConvenienceHUDPresentation {
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIView *rootView = rootViewController.view;

    self.hideExpectation = [self expectationWithDescription:@"The hudWasHidden: delegate should have been called."];

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:rootView animated:YES];
    hud.delegate = self;

    XCTAssertNotNil(hud, @"A HUD should be created.");
    MBTestHUDIsVisible(hud, rootView);

    XCTAssertEqual(hud.bezelView.alpha, 1.f, @"The HUD should be visible.");
    XCTAssertTrue([hud.bezelView.layer.animationKeys containsObject:@"opacity"], @"The opacity should be animated.");

    XCTAssertEqualObjects([MBProgressHUD HUDForView:rootView], hud, @"The HUD should be found via the convenience operation.");

    XCTAssertTrue([MBProgressHUD hideHUDForView:rootView animated:YES], @"The HUD should be found and removed.");

    XCTAssertTrue([rootView.subviews containsObject:hud], @"The HUD should still be part of the view hierarchy.");
    XCTAssertEqual(hud.alpha, 1.f, @"The hud should still be visible.");
    XCTAssertEqualObjects(hud.superview, rootView, @"The hud should be added to the view.");
    XCTAssertEqual(hud.bezelView.alpha, 0.f, @"The HUD bezel should be animated out.");
    XCTAssertTrue([hud.bezelView.layer.animationKeys containsObject:@"opacity"], @"The opacity should be animated.");

    weakify(self);
    self.hideChecks = ^{
        strongify(self);
        MBTestHUDIsHidenAndRemoved(hud, rootView);

        XCTAssertFalse([MBProgressHUD hideHUDForView:rootView animated:YES], @"A subsequent HUD hide operation should fail.");
    };

    [self waitForExpectationsWithTimeout:5. handler:nil];
}

- (void)testCompletionBlock {
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIView *rootView = rootViewController.view;

    self.hideExpectation = [self expectationWithDescription:@"The hudWasHidden: delegate should have been called."];
    XCTestExpectation *completionExpectation = [self expectationWithDescription:@"The completionBlock: should have been called."];

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:rootView animated:YES];
    hud.delegate = self;
    hud.completionBlock = ^{
        [completionExpectation fulfill];
    };

    [hud hideAnimated:YES];

    [self waitForExpectationsWithTimeout:5. handler:nil];
}

#pragma mark - Delay

- (void)testDelayedHide {
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIView *rootView = rootViewController.view;

    self.hideExpectation = [self expectationWithDescription:@"The hudWasHidden: delegate should have been called."];

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:rootView animated:NO];
    hud.delegate = self;

    XCTAssertNotNil(hud, @"A HUD should be created.");

    [hud hideAnimated:NO afterDelay:2];

    MBTestHUDIsVisible(hud, rootView);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        MBTestHUDIsVisible(hud, rootView);
    });

    XCTestExpectation *hideCheckExpectation = [self expectationWithDescription:@"Hide check"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // After the grace time passes, the HUD should still not be shown.
        MBTestHUDIsHidenAndRemoved(hud, rootView);
        [hideCheckExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:5. handler:nil];

    MBTestHUDIsHidenAndRemoved(hud, rootView);
}

#pragma mark - Ruse

- (void)testNonAnimatedHudReuse {
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIView *rootView = rootViewController.view;

    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:rootView];
    [rootView addSubview:hud];
    [hud showAnimated:NO];

    XCTAssertNotNil(hud, @"A HUD should be created.");

    [hud hideAnimated:NO];
    [hud showAnimated:NO];

    MBTestHUDIsVisible(hud, rootView);

    [hud hideAnimated:NO];
    [hud removeFromSuperview];
}

- (void)testUnfinishedHidingAnimation {
  UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
  UIView *rootView = rootViewController.view;

  MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:rootView animated:NO];

  [hud hideAnimated:YES];

  // Cancel all animations. It will cause `UIView+animate...` to call completionBlock with `finished = NO`.
  // It's same as if you call `[hud hideAnimated:YES]` while the app is in background.
  [hud.bezelView.layer removeAllAnimations];
  [hud.backgroundView.layer removeAllAnimations];

  XCTestExpectation *hideCheckExpectation = [self expectationWithDescription:@"Hide check"];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    // After the grace time passes, the HUD should still not be shown.
    MBTestHUDIsHidenAndRemoved(hud, rootView);
    [hideCheckExpectation fulfill];
  });

  [self waitForExpectationsWithTimeout:5. handler:nil];

  MBTestHUDIsHidenAndRemoved(hud, rootView);
}

- (void)testAnimatedImmediateHudReuse {
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIView *rootView = rootViewController.view;

    XCTestExpectation *hideExpectation = [self expectationWithDescription:@"The hud should have been hidden."];

    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:rootView];
    [rootView addSubview:hud];
    [hud showAnimated:YES];

    XCTAssertNotNil(hud, @"A HUD should be created.");

    [hud hideAnimated:YES];
    [hud showAnimated:YES];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        MBTestHUDIsVisible(hud, rootView);

        [hud hideAnimated:NO];
        [hud removeFromSuperview];

        [hideExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:5. handler:nil];
}

#pragma mark - Min show time

- (void)testMinShowTime {
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIView *rootView = rootViewController.view;

    self.hideExpectation = [self expectationWithDescription:@"The hudWasHidden: delegate should have been called."];

    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:rootView];
    hud.delegate = self;
    hud.removeFromSuperViewOnHide = YES;
    hud.minShowTime = 2.;
    [rootView addSubview:hud];
    [hud showAnimated:YES];

    XCTAssertNotNil(hud, @"A HUD should be created.");

    [hud hideAnimated:YES];

    __block BOOL checkedAfterOneSecond = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Check that the hud is still visible
        MBTestHUDIsVisible(hud, rootView);
        checkedAfterOneSecond = YES;
    });

    weakify(self);
    self.hideChecks = ^{
        strongify(self);
        XCTAssertTrue(checkedAfterOneSecond);
    };

    [self waitForExpectationsWithTimeout:5. handler:nil];

    MBTestHUDIsHidenAndRemoved(hud, rootView);
}

#pragma mark - Grace time

- (void)testGraceTime {
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIView *rootView = rootViewController.view;

    self.hideExpectation = [self expectationWithDescription:@"The hudWasHidden: delegate should have been called."];

    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:rootView];
    hud.delegate = self;
    hud.removeFromSuperViewOnHide = YES;
    hud.graceTime = 2.;
    [rootView addSubview:hud];
    [hud showAnimated:YES];

    XCTAssertNotNil(hud, @"A HUD should be created.");

    // The HUD should be added to the view but still hidden
    XCTAssertEqualObjects(hud.superview, rootView, @"The hud should be added to the view."); \
    XCTAssertEqual(hud.alpha, 0.f, @"The HUD should not be visible."); \
    XCTAssertFalse(hud.hidden, @"The HUD should be visible."); \
    XCTAssertEqual(hud.bezelView.alpha, 0.f, @"The HUD should not be visible."); \


    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // The HUD should be added to the view but still hidden
        XCTAssertEqualObjects(hud.superview, rootView, @"The hud should be added to the view."); \
        XCTAssertEqual(hud.alpha, 0.f, @"The HUD should not be visible."); \
        XCTAssertFalse(hud.hidden, @"The HUD should be visible."); \
        XCTAssertEqual(hud.bezelView.alpha, 0.f, @"The HUD should not be visible."); \
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // After the grace time passes, the HUD should be shown.
        MBTestHUDIsVisible(hud, rootView);
        [hud hideAnimated:YES];
    });

    [self waitForExpectationsWithTimeout:5. handler:nil];

    MBTestHUDIsHidenAndRemoved(hud, rootView);
}

- (void)testHideBeforeGraceTimeElapsed {
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIView *rootView = rootViewController.view;

    self.hideExpectation = [self expectationWithDescription:@"The hudWasHidden: delegate should have been called."];

    MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:rootView];
    hud.delegate = self;
    hud.removeFromSuperViewOnHide = YES;
    hud.graceTime = 2.;
    [rootView addSubview:hud];
    [hud showAnimated:YES];

    XCTAssertNotNil(hud, @"A HUD should be created.");

    // The HUD should be added to the view but still hidden
    XCTAssertEqualObjects(hud.superview, rootView, @"The hud should be added to the view."); \
    XCTAssertEqual(hud.alpha, 0.f, @"The HUD should not be visible."); \
    XCTAssertFalse(hud.hidden, @"The HUD should be visible."); \
    XCTAssertEqual(hud.bezelView.alpha, 0.f, @"The HUD should not be visible."); \

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // The HUD should be added to the view but still hidden
        XCTAssertEqualObjects(hud.superview, rootView, @"The hud should be added to the view."); \
        XCTAssertEqual(hud.alpha, 0.f, @"The HUD should not be visible."); \
        XCTAssertFalse(hud.hidden, @"The HUD should be visible."); \
        XCTAssertEqual(hud.bezelView.alpha, 0.f, @"The HUD should not be visible."); \
        [hud hideAnimated:YES];
    });

    XCTestExpectation *hideCheckExpectation = [self expectationWithDescription:@"Hide check"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // After the grace time passes, the HUD should still not be shown.
        MBTestHUDIsHidenAndRemoved(hud, rootView);
        [hideCheckExpectation fulfill];
    });

    [self waitForExpectationsWithTimeout:5. handler:nil];

    MBTestHUDIsHidenAndRemoved(hud, rootView);
}

#pragma mark - MBProgressHUDDelegate

- (void)hudWasHidden:(MBProgressHUD *)hud {
    if (self.hideChecks) self.hideChecks();
    self.hideChecks = nil;

    [self.hideExpectation fulfill];
    self.hideExpectation = nil;
}

@end
