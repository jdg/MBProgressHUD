//
//  HudDemoAppDelegate.h
//  HudDemo
//
//  Created by Matej Bukovinski on 2.4.09.
//  Copyright bukovinski.com 2009. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HudDemoViewController;

@interface HudDemoAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    HudDemoViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet HudDemoViewController *viewController;

@end

