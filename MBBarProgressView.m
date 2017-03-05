//
//  MBBarProgressView.m
//  MBProgressHUD
//
//  Created by Goff Marocchi on 05/03/2017.
//  Copyright © 2017 Matej Bukovinski. All rights reserved.
//

#import "MBBarProgressView.h"

@implementation MBBarProgressView

#pragma mark - Lifecycle

- (id)init {
    return [self initWithFrame:CGRectMake(.0f, .0f, 120.0f, 20.0f)];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _progress = 0.f;
        _lineColor = [UIColor whiteColor];
        _progressColor = [UIColor whiteColor];
        _progressRemainingColor = [UIColor clearColor];
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}

#pragma mark - Layout

- (CGSize)intrinsicContentSize {
    BOOL isPreiOS7 = kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0;
    return CGSizeMake(120.f, isPreiOS7 ? 20.f : 10.f);
}

#pragma mark - Properties

- (void)setProgress:(float)progress {
    if (progress != _progress) {
        _progress = progress;
        [self setNeedsDisplay];
    }
}

- (void)setProgressColor:(UIColor *)progressColor {
    NSAssert(progressColor, @"The color should not be nil.");
    if (progressColor != _progressColor && ![progressColor isEqual:_progressColor]) {
        _progressColor = progressColor;
        [self setNeedsDisplay];
    }
}

- (void)setProgressRemainingColor:(UIColor *)progressRemainingColor {
    NSAssert(progressRemainingColor, @"The color should not be nil.");
    if (progressRemainingColor != _progressRemainingColor && ![progressRemainingColor isEqual:_progressRemainingColor]) {
        _progressRemainingColor = progressRemainingColor;
        [self setNeedsDisplay];
    }
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetLineWidth(context, 2);
    CGContextSetStrokeColorWithColor(context,[_lineColor CGColor]);
    CGContextSetFillColorWithColor(context, [_progressRemainingColor CGColor]);
    
    // Draw background
    CGFloat radius = (rect.size.height / 2) - 2;
    CGContextMoveToPoint(context, 2, rect.size.height/2);
    CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius);
    CGContextAddLineToPoint(context, rect.size.width - radius - 2, 2);
    CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius);
    CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius);
    CGContextAddLineToPoint(context, radius + 2, rect.size.height - 2);
    CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height/2, radius);
    CGContextFillPath(context);
    
    // Draw border
    CGContextMoveToPoint(context, 2, rect.size.height/2);
    CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius);
    CGContextAddLineToPoint(context, rect.size.width - radius - 2, 2);
    CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius);
    CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius);
    CGContextAddLineToPoint(context, radius + 2, rect.size.height - 2);
    CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height/2, radius);
    CGContextStrokePath(context);
    
    CGContextSetFillColorWithColor(context, [_progressColor CGColor]);
    radius = radius - 2;
    CGFloat amount = self.progress * rect.size.width;
    
    // Progress in the middle area
    if (amount >= radius + 4 && amount <= (rect.size.width - radius - 4)) {
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
        CGContextAddLineToPoint(context, amount, 4);
        CGContextAddLineToPoint(context, amount, radius + 4);
        
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
        CGContextAddLineToPoint(context, amount, rect.size.height - 4);
        CGContextAddLineToPoint(context, amount, radius + 4);
        
        CGContextFillPath(context);
    }
    
    // Progress in the right arc
    else if (amount > radius + 4) {
        CGFloat x = amount - (rect.size.width - radius - 4);
        
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
        CGContextAddLineToPoint(context, rect.size.width - radius - 4, 4);
        CGFloat angle = -acos(x/radius);
        if (isnan(angle)) angle = 0;
        CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height/2, radius, M_PI, angle, 0);
        CGContextAddLineToPoint(context, amount, rect.size.height/2);
        
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
        CGContextAddLineToPoint(context, rect.size.width - radius - 4, rect.size.height - 4);
        angle = acos(x/radius);
        if (isnan(angle)) angle = 0;
        CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height/2, radius, -M_PI, angle, 1);
        CGContextAddLineToPoint(context, amount, rect.size.height/2);
        
        CGContextFillPath(context);
    }
    
    // Progress is in the left arc
    else if (amount < radius + 4 && amount > 0) {
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
        CGContextAddLineToPoint(context, radius + 4, rect.size.height/2);
        
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
        CGContextAddLineToPoint(context, radius + 4, rect.size.height/2);
        
        CGContextFillPath(context);
    }
}

@end
