//
//  MBBackgroundView.m
//  MBProgressHUD
//
//  Created by Goff Marocchi on 05/03/2017.
//  Copyright © 2017 Matej Bukovinski. All rights reserved.
//

#import "MBBackgroundView.h"

#import "ProgressBackgroundViewing.h"

@interface MBBackgroundView ()

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 || TARGET_OS_TV
@property UIVisualEffectView *effectView;
#endif
#if !TARGET_OS_TV
@property UIToolbar *toolbar;
#endif

@end

@implementation MBBackgroundView

@synthesize style=_style;
@synthesize color=_color;

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0) {
            _style = ProgressHUDBackgroundStyleBlur;
            if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
                _color = [UIColor colorWithWhite:0.8f alpha:0.6f];
            } else {
                _color = [UIColor colorWithWhite:0.95f alpha:0.6f];
            }
        } else {
            _style = ProgressHUDBackgroundStyleSolidColor;
            _color = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        }
        
        self.clipsToBounds = YES;
        
        [self updateForBackgroundStyle];
    }
    return self;
}

#pragma mark - Layout

- (CGSize)intrinsicContentSize {
    // Smallest size possible. Content pushes against this.
    return CGSizeZero;
}

#pragma mark - Appearance

- (void)setStyle:(ProgressHUDBackgroundStyle)style {
    if (style == ProgressHUDBackgroundStyleBlur && kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0) {
        style = ProgressHUDBackgroundStyleSolidColor;
    }
    if (_style != style) {
        _style = style;
        [self updateForBackgroundStyle];
    }
}

- (void)setColor:(UIColor *)color {
    NSAssert(color, @"The color should not be nil.");
    if (color != _color && ![color isEqual:_color]) {
        _color = color;
        [self updateViewsForColor:color];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Views

- (void)updateForBackgroundStyle {
    ProgressHUDBackgroundStyle style = self.style;
    if (style == ProgressHUDBackgroundStyleBlur) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 || TARGET_OS_TV
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
            UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
            UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
            [self addSubview:effectView];
            effectView.frame = self.bounds;
            effectView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
            self.backgroundColor = self.color;
            self.layer.allowsGroupOpacity = NO;
            self.effectView = effectView;
        } else {
#endif
#if !TARGET_OS_TV
            UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectInset(self.bounds, -100.f, -100.f)];
            toolbar.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
            toolbar.barTintColor = self.color;
            toolbar.translucent = YES;
            [self addSubview:toolbar];
            self.toolbar = toolbar;
#endif
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 || TARGET_OS_TV
        }
#endif
    } else {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 || TARGET_OS_TV
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
            [self.effectView removeFromSuperview];
            self.effectView = nil;
        } else {
#endif
#if !TARGET_OS_TV
            [self.toolbar removeFromSuperview];
            self.toolbar = nil;
#endif
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 || TARGET_OS_TV
        }
#endif
        self.backgroundColor = self.color;
    }
}

- (void)updateViewsForColor:(UIColor *)color {
    if (self.style == ProgressHUDBackgroundStyleBlur) {
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
            self.backgroundColor = self.color;
        } else {
#if !TARGET_OS_TV
            self.toolbar.barTintColor = color;
#endif
        }
    } else {
        self.backgroundColor = self.color;
    }
}

@end
