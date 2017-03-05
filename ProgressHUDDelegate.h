//
//  ProgressHUDDelegate.h
//  MBProgressHUD
//
//  Created by Goff Marocchi on 05/03/2017.
//  Copyright © 2017 Matej Bukovinski. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ProgressHUD;

@protocol ProgressHUDDelegate <NSObject>

- (void)hudWasHidden:(id<ProgressHUD>)hud;

@end
