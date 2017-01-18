//
//  MBHudDemoTVViewController.m
//  HudDemoTV
//
//  Created by Matej Bukovinski on 17. 07. 16.
//  Copyright © 2016 Matej Bukovinski. All rights reserved.
//

#import "MBHudDemoTVViewController.h"
#import "MBProgressHUD.h"

@implementation MBHudDemoTVViewController

- (IBAction)showHud:(UIButton *)sender {
    sender.enabled = NO;

    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];

    // Set the determinate mode to show task progress.
    hud.mode = MBProgressHUDModeDeterminate;
    hud.label.text = NSLocalizedString(@"Loading...", @"HUD loading title");

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // Do something useful in the background and update the HUD periodically.
        [self doSomeWorkWithProgress];
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud hideAnimated:YES];
            sender.enabled = YES;
        });
    });
}

- (void)doSomeWorkWithProgress {
    // This just increases the progress indicator in a loop.
    float progress = 0.0f;
    while (progress < 1.0f) {
        progress += 0.01f;
        dispatch_async(dispatch_get_main_queue(), ^{
            // Instead we could have also passed a reference to the HUD
            // to the HUD to myProgressTask as a method parameter.
            [MBProgressHUD HUDForView:self.view].progress = progress;
        });
        usleep(50000);
    }
}

@end
