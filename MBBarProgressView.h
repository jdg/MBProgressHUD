//
//  MBBarProgressView.h
//  MBProgressHUD
//
//  Created by Goff Marocchi on 05/03/2017.
//  Copyright © 2017 Matej Bukovinski. All rights reserved.
//

#import <UIKit/UIKit.h>


/**
 * A flat bar progress view.
 */
@interface MBBarProgressView : UIView

/**
 * Progress (0.0 to 1.0)
 */
@property (nonatomic, assign) float progress;

/**
 * Bar border line color.
 * Defaults to white [UIColor whiteColor].
 */
@property (nonatomic, strong) UIColor *lineColor;

/**
 * Bar background color.
 * Defaults to clear [UIColor clearColor];
 */
@property (nonatomic, strong) UIColor *progressRemainingColor;

/**
 * Bar progress color.
 * Defaults to white [UIColor whiteColor].
 */
@property (nonatomic, strong) UIColor *progressColor;

@end
