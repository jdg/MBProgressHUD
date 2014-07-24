//
//  MBProgressHUD+GlobalHUD.m
//  Remind101
//
//  Created by Rex Fenley on 11/9/13.
//  Copyright (c) 2013 Remind101. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MBProgressHUD+GlobalHUD.h"

#import <objc/runtime.h>

@implementation MBProgressHUD (GlobalHUD)

static void * const kHUDCountStorageKey = (void *)&kHUDCountStorageKey;
static MBProgressHUD * globalHUD;

+ (void)renewGlobalHUD
{
    NSArray *windows = [[UIApplication sharedApplication] windows];
    UIWindow *window = [windows lastObject];
    
    CGFloat currentTopWindowLevel = 1500;
    
    if (window.windowLevel > currentTopWindowLevel) {
        // For reference, 1996-2000 is UIAlertView. Unfortunately we don't have safe access to those values.
        // Make sure we're not attaching to an alert view that's about to dismiss.
        for (NSInteger i = windows.count - 1; i >= 0; i--) {
            window = windows[i];
            if (window.windowLevel <= currentTopWindowLevel) break;
        }
    }
    
    globalHUD = [[MBProgressHUD alloc] initWithWindow:window];
    [window addSubview:globalHUD];
    
    globalHUD.delegate = globalHUD;
}

// NSInteger protects against over dismissing.
- (NSInteger)hudCount
{
    NSNumber *hudCount = objc_getAssociatedObject(self, kHUDCountStorageKey);
    
    if (hudCount) return [hudCount integerValue];
    else return 0;
}

- (void)setHudCount:(NSInteger)hudCount
{
    NSNumber *hudCountObject = [NSNumber numberWithInteger:hudCount];
    objc_setAssociatedObject(self, kHUDCountStorageKey, hudCountObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Displaying/Dismissing

+ (void)displayGlobalHUD
{
    if (!globalHUD || globalHUD.hudCount == 0) {
        [MBProgressHUD renewGlobalHUD];
        [globalHUD show:YES];
    }
    globalHUD.hudCount += 1;
}

+ (void)dismissGlobalHUD
{
    globalHUD.hudCount -= 1;
    if (globalHUD.hudCount == 0) {
        [globalHUD hide:NO];
    }
}

#pragma mark - MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud
{
	// Remove HUD from screen when the HUD was hidded
	[hud removeFromSuperview];
}

@end
