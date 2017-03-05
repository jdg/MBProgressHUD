//
//  ProgressBackgroundViewing.h
//  MBProgressHUD
//
//  Created by Goff Marocchi on 05/03/2017.
//  Copyright © 2017 Matej Bukovinski. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ProgressHUDBackgroundStyle) {
    /// Solid color background
    ProgressHUDBackgroundStyleSolidColor,
    /// UIVisualEffectView or UIToolbar.layer background view
    ProgressHUDBackgroundStyleBlur
};

@protocol ProgressBackgroundViewing <NSObject>

/**
 * The background style.
 * Defaults to ProgressHUDBackgroundStyleBlur on iOS 7 or later and ProgressHUDBackgroundStyleSolidColor otherwise.
 * @note Due to iOS 7 not supporting UIVisualEffectView, the blur effect differs slightly between iOS 7 and later versions.
 */
@property (nonatomic) ProgressHUDBackgroundStyle style;

/**
 * The background color or the blur tint color.
 * @note Due to iOS 7 not supporting UIVisualEffectView, the blur effect differs slightly between iOS 7 and later versions.
 */
@property (nonatomic, strong) UIColor *color;

@end
