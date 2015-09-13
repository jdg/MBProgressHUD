//
// MBProgressHUD.m
// Version 0.9.1
// Created by Matej Bukovinski on 2.4.09.
//

#import "MBProgressHUD.h"
#import <tgmath.h>


#ifndef kCFCoreFoundationVersionNumber_iOS_7_0
	#define kCFCoreFoundationVersionNumber_iOS_7_0 847.20
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_8_0
	#define kCFCoreFoundationVersionNumber_iOS_8_0 1129.15
#endif

#define MBMainThreadAssert() NSAssert([NSThread isMainThread], @"MBProgressHUD needs to be accessed on the main thread.");


static const CGFloat MBDefaultPadding = 4.f;
static const CGFloat MBDefaultLabelFontSize = 16.f;
static const CGFloat MBDefaultDetailsLabelFontSize = 12.f;


@interface MBProgressHUD ()

@property (nonatomic, assign) BOOL useAnimation;
@property (nonatomic, assign, getter=hasFinished) BOOL finished;
@property (nonatomic, assign, readwrite) CGSize size;
@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, strong) NSTimer *graceTimer;
@property (nonatomic, strong) NSTimer *minShowTimer;
@property (nonatomic, strong) NSDate *showStarted;
@property (nonatomic, strong) NSArray *paddingConstraints;
@property (nonatomic, strong) UIView *topSpacer;
@property (nonatomic, strong) UIView *bottomSpacer;

// Deprecated
@property (copy) MBProgressHUDCompletionBlock completionBlock;
@property (assign) BOOL taskInProgress;
@property (strong, nonatomic) UIColor *activityIndicatorColor;

@end


@implementation MBProgressHUD

#pragma mark - Class methods

+ (instancetype)showHUDAddedTo:(UIView *)view animated:(BOOL)animated {
	MBProgressHUD *hud = [[self alloc] initWithView:view];
	hud.removeFromSuperViewOnHide = YES;
	[view addSubview:hud];
    [hud showAnimated:animated];
	return hud;
}

+ (BOOL)hideHUDForView:(UIView *)view animated:(BOOL)animated {
	MBProgressHUD *hud = [self HUDForView:view];
	if (hud != nil) {
		hud.removeFromSuperViewOnHide = YES;
		[hud hideAnimated:animated];
		return YES;
	}
	return NO;
}

+ (MBProgressHUD *)HUDForView:(UIView *)view {
	NSEnumerator *subviewsEnum = [view.subviews reverseObjectEnumerator];
	for (UIView *subview in subviewsEnum) {
		if ([subview isKindOfClass:self]) {
			return (MBProgressHUD *)subview;
		}
	}
	return nil;
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		// Set default values for properties
		_animationType = MBProgressHUDAnimationFade;
		_mode = MBProgressHUDModeIndeterminate;
		_margin = 20.0f;

        // Default color, depending on the current iOS version
        BOOL isLegacy = kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0;
        _color = isLegacy ? [UIColor whiteColor] : [UIColor colorWithWhite:0.f alpha:0.7f];
		// Transparent background
		self.opaque = NO;
		self.backgroundColor = [UIColor clearColor];
		// Make it invisible for now
		self.alpha = 0.0f;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.layer.allowsGroupOpacity = NO;

		[self setupViews];
		[self updateIndicators];
		[self registerForNotifications];
	}
	return self;
}

- (id)initWithView:(UIView *)view {
	NSAssert(view, @"View must not be nil.");
	return [self initWithFrame:view.bounds];
}

- (void)dealloc {
	[self unregisterFromNotifications];
}

#pragma mark - Show & hide

- (void)showAnimated:(BOOL)animated {
    MBMainThreadAssert();
	self.useAnimation = animated;
    self.finished = NO;
	// If the grace time is set postpone the HUD display
	if (self.graceTime > 0.0) {
        NSTimer *timer = [NSTimer timerWithTimeInterval:self.graceTime target:self selector:@selector(handleGraceTimer:) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        self.graceTimer = timer;
	} 
	// ... otherwise show the HUD imediately 
	else {
		[self showUsingAnimation:self.useAnimation];
	}
}

- (void)hideAnimated:(BOOL)animated {
    MBMainThreadAssert();
	self.useAnimation = animated;
    self.finished = YES;
	// If the minShow time is set, calculate how long the hud was shown,
	// and pospone the hiding operation if necessary
	if (self.minShowTime > 0.0 && self.showStarted) {
		NSTimeInterval interv = [[NSDate date] timeIntervalSinceDate:self.showStarted];
		if (interv < self.minShowTime) {
            NSTimer *timer = [NSTimer timerWithTimeInterval:(self.minShowTime - interv) target:self selector:@selector(handleMinShowTimer:) userInfo:nil repeats:NO];
            [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
            self.minShowTimer = timer;
			return;
		} 
	}
	// ... otherwise hide the HUD immediately
	[self hideUsingAnimation:self.useAnimation];
}

- (void)hideAnimated:(BOOL)animated afterDelay:(NSTimeInterval)delay {
	[self performSelector:@selector(hideDelayed:) withObject:[NSNumber numberWithBool:animated] afterDelay:delay];
}

- (void)hideDelayed:(NSNumber *)animated {
	[self hideAnimated:[animated boolValue]];
}

#pragma mark - Timer callbacks

- (void)handleGraceTimer:(NSTimer *)theTimer {
	// Show the HUD only if the task is still running
	if (self.hasFinished) {
		[self showUsingAnimation:self.useAnimation];
	}
}

- (void)handleMinShowTimer:(NSTimer *)theTimer {
	[self hideUsingAnimation:self.useAnimation];
}

#pragma mark - View Hierrarchy

- (void)didMoveToSuperview {
    [self updateForCurrentOrientationAnimated:NO];
}

#pragma mark - Internal show & hide operations

- (void)showUsingAnimation:(BOOL)animated {
    // Cancel any scheduled hideDelayed: calls
    [NSObject cancelPreviousPerformRequestsWithTarget:self];

	self.showStarted = [NSDate date];
    self.alpha = 1.f;

	if (animated) {
        [self animateIn:YES withType:self.animationType completion:NULL];
	} else {
		self.bezelView.alpha = 1.0f;
	}
}

- (void)hideUsingAnimation:(BOOL)animated {
	if (animated && self.showStarted) {
        [self animateIn:NO withType:self.animationType completion:^(BOOL finished) {
            [self done];
        }];
	} else {
		self.bezelView.alpha = 0.0f;
		[self done];
	}
	self.showStarted = nil;
}

- (void)animateIn:(BOOL)animatingIn withType:(MBProgressHUDAnimation)type completion:(void(^)(BOOL finished))completion {
    // Automatically determine the correct
    if (type == MBProgressHUDAnimationZoom) {
        type = animatingIn ? MBProgressHUDAnimationZoomIn : MBProgressHUDAnimationZoomOut;
    }

    CGAffineTransform small = CGAffineTransformMakeScale(0.5f, 0.5f);
    CGAffineTransform large = CGAffineTransformMakeScale(1.5f, 1.5f);

    // Set starting state
    UIView *bezelView = self.bezelView;
    if (animatingIn && bezelView.alpha == 0.f && type == MBProgressHUDAnimationZoomIn) {
        bezelView.transform = small;
    } else if (animatingIn && bezelView.alpha == 0.f && type == MBProgressHUDAnimationZoomOut) {
        bezelView.transform = large;
    }

    // Perform animations
    dispatch_block_t animations = ^{
        if (animatingIn) {
            bezelView.transform = CGAffineTransformIdentity;
        } else if (!animatingIn && type == MBProgressHUDAnimationZoomIn) {
            bezelView.transform = large;
        } else if (!animatingIn && type == MBProgressHUDAnimationZoomOut) {
            bezelView.transform = small;
        }
        bezelView.alpha = animatingIn ? 1.f : 0.f;
    };

    // Spring animations are nicer, but only available on iOS 7+
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0) {
        [UIView animateWithDuration:0.3 delay:0. usingSpringWithDamping:1.f initialSpringVelocity:0.f options:UIViewAnimationOptionBeginFromCurrentState animations:animations completion:completion];
        return;
    }
#endif
    [UIView animateWithDuration:0.3 delay:0. options:UIViewAnimationOptionBeginFromCurrentState animations:animations completion:completion];
}

- (void)done {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	self.alpha = 0.0f;
	if (self.removeFromSuperViewOnHide) {
		[self removeFromSuperview];
	}
	if (self.completionBlock) {
		self.completionBlock();
		self.completionBlock = NULL;
	}

    id<MBProgressHUDDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(hudWasHidden:)]) {
		[delegate performSelector:@selector(hudWasHidden:) withObject:self];
	}
}

#pragma mark - UI

- (void)setupViews {
    UIColor *defaultColor = self.color;

    MBBackgroundView *bezelView = [MBBackgroundView new];
    bezelView.translatesAutoresizingMaskIntoConstraints = NO;
    bezelView.layer.cornerRadius = 5.f;
    bezelView.alpha = 0.f;
    [self addSubview:bezelView];
    _bezelView = bezelView;

	UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
	label.adjustsFontSizeToFitWidth = NO;
	label.textAlignment = NSTextAlignmentCenter;
	label.opaque = NO;
	label.backgroundColor = [UIColor clearColor];
	label.textColor = defaultColor;
	label.font = [UIFont boldSystemFontOfSize:MBDefaultLabelFontSize];;
	[bezelView addSubview:label];
    _label = label;
	
	UILabel *detailsLabel = [UILabel new];
    detailsLabel.translatesAutoresizingMaskIntoConstraints = NO;
	detailsLabel.adjustsFontSizeToFitWidth = NO;
	detailsLabel.textAlignment = NSTextAlignmentCenter;
	detailsLabel.opaque = NO;
	detailsLabel.backgroundColor = [UIColor clearColor];
	detailsLabel.textColor = defaultColor;
	detailsLabel.numberOfLines = 0;
	detailsLabel.font = [UIFont boldSystemFontOfSize:MBDefaultDetailsLabelFontSize];
	[bezelView addSubview:detailsLabel];
    _detailsLabel = detailsLabel;

    UIView *topSpacer = [UIView new];
    topSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    topSpacer.hidden = YES;
    [bezelView addSubview:topSpacer];
    _topSpacer = topSpacer;

    UIView *bottomSpacer = [UIView new];
    bottomSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    bottomSpacer.hidden = YES;
    [bezelView addSubview:bottomSpacer];
    _bottomSpacer = bottomSpacer;
}

- (void)updateIndicators {
    UIView *indicator = self.indicator;
	BOOL isActivityIndicator = [indicator isKindOfClass:[UIActivityIndicatorView class]];
	BOOL isRoundIndicator = [indicator isKindOfClass:[MBRoundProgressView class]];

    MBProgressHUDMode mode = self.mode;
	if (mode == MBProgressHUDModeIndeterminate) {
		if (!isActivityIndicator) {
			// Update to indeterminate indicator
			[indicator removeFromSuperview];
			indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
			[(UIActivityIndicatorView *)indicator startAnimating];
			[self.bezelView addSubview:indicator];
		}
	}
	else if (mode == MBProgressHUDModeDeterminateHorizontalBar) {
		// Update to bar determinate indicator
		[indicator removeFromSuperview];
        indicator = [[MBBarProgressView alloc] init];
		[self.bezelView addSubview:indicator];
	}
	else if (mode == MBProgressHUDModeDeterminate || mode == MBProgressHUDModeAnnularDeterminate) {
		if (!isRoundIndicator) {
			// Update to determinante indicator
			[indicator removeFromSuperview];
            indicator = [[MBRoundProgressView alloc] init];
			[self.bezelView addSubview:indicator];
		}
		if (mode == MBProgressHUDModeAnnularDeterminate) {
			[(MBRoundProgressView *)indicator setAnnular:YES];
		}
	} 
	else if (mode == MBProgressHUDModeCustomView && self.customView != indicator) {
		// Update custom view indicator
		[indicator removeFromSuperview];
		indicator = self.customView;
		[self.bezelView addSubview:indicator];
	}
    else if (mode == MBProgressHUDModeText) {
		[indicator removeFromSuperview];
		indicator = nil;
	}
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicator = indicator;

    if ([indicator respondsToSelector:@selector(setProgress:)]) {
        [(id)indicator setValue:@(self.progress) forKey:@"progress"];
    }

    [self updateViewsForColor:self.color];
    [self setNeedsUpdateConstraints];
}

- (void)updateViewsForColor:(UIColor *)color {
    if (!color) return;

    self.label.textColor = color;
    self.detailsLabel.textColor = color;

    // Deprecated
    if (self.activityIndicatorColor) {
        color = self.activityIndicatorColor;
    }

    UIView *indicator = self.indicator;
    if ([indicator isKindOfClass:[UIActivityIndicatorView class]]) {
        ((UIActivityIndicatorView *)indicator).color = color;
    } else if ([indicator isKindOfClass:[MBRoundProgressView class]]) {
        ((MBRoundProgressView *)indicator).progressTintColor = color;
        ((MBRoundProgressView *)indicator).backgroundTintColor = [color colorWithAlphaComponent:0.1];
    } else if ([indicator isKindOfClass:[MBBarProgressView class]]) {
        ((MBBarProgressView *)indicator).progressColor = color;
        ((MBBarProgressView *)indicator).lineColor = color;
    }
}

#pragma mark - Layout

- (void)updateConstraints {
    [super updateConstraints];

    UIView *bezel = self.bezelView;
    CGFloat margin = self.margin;
    NSDictionary *metrics = @{@"margin": @(margin)};

    NSMutableArray *subviews = [NSMutableArray arrayWithObjects:self.topSpacer, self.label, self.detailsLabel, self.bottomSpacer, nil];
    if (self.indicator) [subviews insertObject:self.indicator atIndex:1];

    // Remove existing constraintes
    [self removeConstraints:self.constraints];
    [bezel removeConstraints:bezel.constraints];

    // Center bezel in container (self)
    CGPoint offset = self.offset;
    [self addConstraint:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.f constant:offset.x]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.f constant:offset.y]];
    // Ensure minimum side margin is kept
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(>=margin)-[bezel]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(bezel)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=margin)-[bezel]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(bezel)]];

    // Minimum bezel size, if set
    CGSize minimumSize = self.minSize;
    if (!CGSizeEqualToSize(minimumSize, CGSizeZero)) {
        NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:minimumSize.width];
        width.priority = 999.f;
        NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:minimumSize.height];
        height.priority = 999.f;
        [bezel addConstraints:@[width, height]];
    }

    // Square aspect ratio, if set
    if (self.square) {
        NSLayoutConstraint *square = [NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeWidth multiplier:1.f constant:0];
        square.priority = 998.f;
        [bezel addConstraint:square];
    }

    // Top and bottom spacing
    UIView *topSpacer = self.topSpacer;
    [topSpacer addConstraint:[NSLayoutConstraint constraintWithItem:topSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:margin]];
    UIView *bottomSpacer = self.bottomSpacer;
    [bottomSpacer addConstraint:[NSLayoutConstraint constraintWithItem:bottomSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:margin]];
    // Top and bottom spaces should be equal
    [bezel addConstraint:[NSLayoutConstraint constraintWithItem:topSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:bottomSpacer attribute:NSLayoutAttributeHeight multiplier:1.f constant:0.f]];

    // Layout subviews in bezel
    NSMutableArray *paddingConstraints = [NSMutableArray new];
    [subviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        // Center in bezel
        [bezel addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeCenterX multiplier:1.f constant:0.f]];
        // Ensure the minimum edge margin is kept
        [bezel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(>=margin)-[view]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(view)]];
        // Element spacing
        if (idx == 0) {
            // First, ensure spacing to bezel edge
            [bezel addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeTop multiplier:1.f constant:0.f]];
        } else if (idx == subviews.count - 1) {
            // Last, ensure spacigin to bezel edge
            [bezel addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeBottom multiplier:1.f constant:0.f]];
        }
        if (idx > 0) {
            // Has previous
            NSLayoutConstraint *padding = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:subviews[idx - 1] attribute:NSLayoutAttributeBottom multiplier:1.f constant:0.f];
            [bezel addConstraint:padding];
            [paddingConstraints addObject:padding];
        }
    }];

    self.paddingConstraints = [paddingConstraints copy];
    [self updatePaddingConstraints];
}

- (void)layoutSubviews {
    [self updatePaddingConstraints];
    [super layoutSubviews];
}

- (void)updatePaddingConstraints {
    // Set padding dynamically, depending on whether the view is visible or not
    __block BOOL hasVisibleAnchestors = NO;
    [self.paddingConstraints enumerateObjectsUsingBlock:^(NSLayoutConstraint *padding, NSUInteger idx, BOOL *stop) {
        UIView *firstView = (UIView *)padding.firstItem;
        UIView *secondView = (UIView *)padding.secondItem;
        BOOL firstVisible = !firstView.hidden && !CGSizeEqualToSize(firstView.intrinsicContentSize, CGSizeZero);
        BOOL secondVisible = !secondView.hidden && !CGSizeEqualToSize(secondView.intrinsicContentSize, CGSizeZero);
        // Set if both views are visible of if there's a visible view on top that yet doesn't have padding
        // added relative to the current view
        padding.constant = (firstVisible && (secondVisible || hasVisibleAnchestors)) ? MBDefaultPadding : 0.f;
        hasVisibleAnchestors |= secondVisible;
    }];
}

#pragma mark - Properties

- (void)setMode:(MBProgressHUDMode)mode {
    if (mode != _mode) {
        _mode = mode;
        [self updateIndicators];
    }
}

- (void)setCustomView:(UIView *)customView {
    if (customView != _customView) {
        _customView = customView;
        if (self.mode == MBProgressHUDModeCustomView) {
            [self updateIndicators];
        }
    }
}

- (void)setOffset:(CGPoint)offset {
    if (!CGPointEqualToPoint(offset, _offset)) {
        _offset = offset;
        [self setNeedsUpdateConstraints];
    }
}

- (void)setMargin:(CGFloat)margin {
    if (margin != margin) {
        _margin = margin;
        [self setNeedsUpdateConstraints];
    }
}

- (void)setMinSize:(CGSize)minSize {
    if (!CGSizeEqualToSize(minSize, _minSize)) {
        _minSize = minSize;
        [self setNeedsUpdateConstraints];
    }
}

- (void)setSquare:(BOOL)square {
    if (square != _square) {
        _square = square;
        [self setNeedsUpdateConstraints];
    }
}

- (void)setProgress:(float)progress {
    if (progress != _progress) {
        _progress = progress;
        UIView *indicator = self.indicator;
        if ([indicator respondsToSelector:@selector(setProgress:)]) {
            [(id)indicator setValue:@(self.progress) forKey:@"progress"];
        }
    }
}

- (void)setColor:(UIColor *)color {
    if (color != _color && ![color isEqual:_color]) {
        _color = color;
        [self updateViewsForColor:color];
    }
}

#pragma mark - Notifications

- (void)registerForNotifications {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	[nc addObserver:self selector:@selector(statusBarOrientationDidChange:)
			   name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)unregisterFromNotifications {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)statusBarOrientationDidChange:(NSNotification *)notification {
	UIView *superview = self.superview;
	if (!superview) {
		return;
	} else {
		[self updateForCurrentOrientationAnimated:YES];
	}
}

- (void)updateForCurrentOrientationAnimated:(BOOL)animated {
    // Stay in sync with the superview in any case
    if (self.superview) {
        self.bounds = self.superview.bounds;
    }

    // Not needed on iOS 8+, compile out when the deployment target allows,
    // to avoid sharedApplication problems on extension targets
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 80000
    // Only needed pre iOS 8 when added to a window
    BOOL iOS8OrLater = kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0;
    if (iOS8OrLater || ![self.superview isKindOfClass:[UIWindow class]]) return;

	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	CGFloat radians = 0;
	if (UIInterfaceOrientationIsLandscape(orientation)) {
        radians = orientation == UIInterfaceOrientationLandscapeLeft ? -(CGFloat)M_PI_2 : (CGFloat)M_PI_2;
		// Window coordinates differ!
		self.bounds = CGRectMake(0, 0, self.bounds.size.height, self.bounds.size.width);
	} else {
        radians = orientation == UIInterfaceOrientationPortraitUpsideDown ? (CGFloat)M_PI : 0.f;
	}

    if (animated) {
        [UIView animateWithDuration:0.3 animations:^{
            self.transform = CGAffineTransformMakeRotation(radians);
        }];
    } else {
        self.transform = CGAffineTransformMakeRotation(radians);
    }
#endif
}

@end


@implementation MBRoundProgressView

#pragma mark - Lifecycle

- (id)init {
	return [self initWithFrame:CGRectMake(0.f, 0.f, 37.f, 37.f)];
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
		_progress = 0.f;
		_annular = NO;
		_progressTintColor = [[UIColor alloc] initWithWhite:1.f alpha:1.f];
		_backgroundTintColor = [[UIColor alloc] initWithWhite:1.f alpha:.1f];
		[self registerForKVO];
	}
	return self;
}

- (void)dealloc {
	[self unregisterFromKVO];
}

#pragma mark - Layout

- (CGSize)intrinsicContentSize {
    return CGSizeMake(37.f, 37.f);
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
	
	CGRect allRect = self.bounds;
	CGRect circleRect = CGRectInset(allRect, 2.0f, 2.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	if (_annular) {
		// Draw background
		BOOL isPreiOS7 = kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0;
		CGFloat lineWidth = isPreiOS7 ? 5.f : 2.f;
		UIBezierPath *processBackgroundPath = [UIBezierPath bezierPath];
		processBackgroundPath.lineWidth = lineWidth;
		processBackgroundPath.lineCapStyle = kCGLineCapButt;
		CGPoint center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
		CGFloat radius = (self.bounds.size.width - lineWidth)/2;
		CGFloat startAngle = - ((float)M_PI / 2); // 90 degrees
		CGFloat endAngle = (2 * (float)M_PI) + startAngle;
		[processBackgroundPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
		[_backgroundTintColor set];
		[processBackgroundPath stroke];
		// Draw progress
		UIBezierPath *processPath = [UIBezierPath bezierPath];
		processPath.lineCapStyle = isPreiOS7 ? kCGLineCapRound : kCGLineCapSquare;
		processPath.lineWidth = lineWidth;
		endAngle = (self.progress * 2 * (float)M_PI) + startAngle;
		[processPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
		[_progressTintColor set];
		[processPath stroke];
	} else {
		// Draw background
		[_progressTintColor setStroke];
		[_backgroundTintColor setFill];
		CGContextSetLineWidth(context, 2.0f);
		CGContextFillEllipseInRect(context, circleRect);
		CGContextStrokeEllipseInRect(context, circleRect);
		// Draw progress
		CGPoint center = CGPointMake(allRect.size.width / 2, allRect.size.height / 2);
		CGFloat radius = (allRect.size.width - 4) / 2;
		CGFloat startAngle = - ((float)M_PI / 2); // 90 degrees
		CGFloat endAngle = (self.progress * 2 * (float)M_PI) + startAngle;
		[_progressTintColor setFill];
		CGContextMoveToPoint(context, center.x, center.y);
		CGContextAddArc(context, center.x, center.y, radius, startAngle, endAngle, 0);
		CGContextClosePath(context);
		CGContextFillPath(context);
	}
}

#pragma mark - KVO

- (void)registerForKVO {
	for (NSString *keyPath in [self observableKeypaths]) {
		[self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:NULL];
	}
}

- (void)unregisterFromKVO {
	for (NSString *keyPath in [self observableKeypaths]) {
		[self removeObserver:self forKeyPath:keyPath];
	}
}

- (NSArray *)observableKeypaths {
	return [NSArray arrayWithObjects:@"progressTintColor", @"backgroundTintColor", @"progress", @"annular", nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	[self setNeedsDisplay];
}

@end


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
		[self registerForKVO];
	}
	return self;
}

- (void)dealloc {
	[self unregisterFromKVO];
}

#pragma mark - Layout

- (CGSize)intrinsicContentSize {
    return CGSizeMake(120.f, 20.f);
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

#pragma mark - KVO

- (void)registerForKVO {
	for (NSString *keyPath in [self observableKeypaths]) {
		[self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:NULL];
	}
}

- (void)unregisterFromKVO {
	for (NSString *keyPath in [self observableKeypaths]) {
		[self removeObserver:self forKeyPath:keyPath];
	}
}

- (NSArray *)observableKeypaths {
	return [NSArray arrayWithObjects:@"lineColor", @"progressRemainingColor", @"progressColor", @"progress", nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	[self setNeedsDisplay];
}

@end


@interface MBBackgroundView ()

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
@property UIVisualEffectView *effectView;
#endif
@property UIToolbar *toolbar;

@end


@implementation MBBackgroundView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0) {
            _style = MBProgressHUDBackgroundStyleBlur;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
            _color = [UIColor colorWithWhite:0.8f alpha:0.6f];
#else
            _color = [UIColor colorWithWhite:0.95f alpha:0.6f];
#endif
        } else {
            _style = MBProgressHUDBackgroundStyleSolidColor;
            _color = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        }

        self.clipsToBounds = YES;

        [self updateForBackgroundStyle];
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Appearance

- (void)setStyle:(MBProgressHUDBackgroundStyle)style {
    if (style == MBProgressHUDBackgroundStyleBlur && kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0) {
        style = MBProgressHUDBackgroundStyleSolidColor;
    }
    if (_style != style) {
        _style = style;
        [self updateForBackgroundStyle];
    }
}

- (void)setColor:(UIColor *)color {
    if (color != _color && ![color isEqual:_color]) {
        _color = color;
        [self updateViewsForColor:color];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Views

- (void)updateForBackgroundStyle {
    MBProgressHUDBackgroundStyle style = self.style;
    if (style == MBProgressHUDBackgroundStyleBlur) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
        [self addSubview:effectView];
        effectView.frame = self.bounds;
        effectView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = self.color;
        self.layer.allowsGroupOpacity = NO;
        self.effectView = effectView;
#else
        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectInset(self.bounds, -100.f, -100.f)];
        toolbar.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        toolbar.barTintColor = self.color;
        toolbar.translucent = YES;
        toolbar.barTintColor = color;
        [self addSubview:toolbar];
        self.toolbar = toolbar;
#endif
    } else {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        [self.effectView removeFromSuperview];
        self.effectView = nil;
#else
        [self.toolbar removeFromSuperview];
        self.toolbar = nil;
#endif
        self.backgroundColor = self.color;
    }
}

- (void)updateViewsForColor:(UIColor *)color {
    if (self.style == MBProgressHUDBackgroundStyleBlur) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        self.backgroundColor = self.color;
#else
        self.toolbar.barTintColor = color;
#endif
    } else {
        self.backgroundColor = self.color;
    }
}

@end


@implementation MBProgressHUD (Deprecated)

#pragma mark - Class

+ (NSUInteger)hideAllHUDsForView:(UIView *)view animated:(BOOL)animated {
    NSArray *huds = [MBProgressHUD allHUDsForView:view];
    for (MBProgressHUD *hud in huds) {
        hud.removeFromSuperViewOnHide = YES;
        [hud hideAnimated:animated];
    }
    return [huds count];
}

+ (NSArray *)allHUDsForView:(UIView *)view {
    NSMutableArray *huds = [NSMutableArray array];
    NSArray *subviews = view.subviews;
    for (UIView *aView in subviews) {
        if ([aView isKindOfClass:self]) {
            [huds addObject:aView];
        }
    }
    return [NSArray arrayWithArray:huds];
}

#pragma mark - Lifecycle

- (id)initWithWindow:(UIWindow *)window {
    return [self initWithView:window];
}

#pragma mark - Show & hide

- (void)show:(BOOL)animated {
    [self showAnimated:animated];
}

- (void)hide:(BOOL)animated {
    [self hideAnimated:animated];
}

- (void)hide:(BOOL)animated afterDelay:(NSTimeInterval)delay {
    [self hideAnimated:animated afterDelay:delay];
}

#pragma mark - Threading

- (void)showWhileExecuting:(SEL)method onTarget:(id)target withObject:(id)object animated:(BOOL)animated {
    [self showAnimated:animated whileExecutingBlock:^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        // Start executing the requested task
        [target performSelector:method withObject:object];
#pragma clang diagnostic pop
    }];
}

- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [self showAnimated:animated whileExecutingBlock:block onQueue:queue completionBlock:NULL];
}

- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block completionBlock:(void (^)())completion {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [self showAnimated:animated whileExecutingBlock:block onQueue:queue completionBlock:completion];
}

- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block onQueue:(dispatch_queue_t)queue {
    [self showAnimated:animated whileExecutingBlock:block onQueue:queue	completionBlock:NULL];
}

- (void)showAnimated:(BOOL)animated whileExecutingBlock:(dispatch_block_t)block onQueue:(dispatch_queue_t)queue
     completionBlock:(MBProgressHUDCompletionBlock)completion {
    self.taskInProgress = YES;
    self.completionBlock = completion;
    dispatch_async(queue, ^(void) {
        block();
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self cleanUp];
        });
    });
    [self showAnimated:animated];
}

- (void)cleanUp {
    self.taskInProgress = NO;
    [self hideAnimated:self.useAnimation];
}

#pragma mark - Labels

- (NSString *)labelText {
    return self.label.text;
}

- (void)setLabelText:(NSString *)labelText {
    MBMainThreadAssert();
    self.label.text = labelText;
}

- (UIFont *)labelFont {
    return self.label.font;
}

- (void)setLabelFont:(UIFont *)labelFont {
    MBMainThreadAssert();
    self.label.font = labelFont;
}

- (UIColor *)labelColor {
    return self.label.textColor;
}

- (void)setLabelColor:(UIColor *)labelColor {
    MBMainThreadAssert();
    self.label.textColor = labelColor;
}

- (NSString *)detailsLabelText {
    return self.detailsLabel.text;
}

- (void)setDetailsLabelText:(NSString *)detailsLabelText {
    MBMainThreadAssert();
    self.detailsLabel.text = detailsLabelText;
}

- (UIFont *)detailsLabelFont {
    return self.detailsLabel.font;
}

- (void)setDetailsLabelFont:(UIFont *)detailsLabelFont {
    MBMainThreadAssert();
    self.detailsLabel.font = detailsLabelFont;
}

- (UIColor *)detailsLabelColor {
    return self.detailsLabel.textColor;
}

- (void)setDetailsLabelColor:(UIColor *)detailsLabelColor {
    MBMainThreadAssert();
    self.detailsLabel.textColor = detailsLabelColor;
}

- (CGFloat)opacity {
    // TODO: forward when appropriate
    return 1.f;
}

- (void)setOpacity:(CGFloat)opacity {
    MBMainThreadAssert();
    // TODO: forward when appropriate
}

- (void)setColor:(UIColor *)color {
    MBMainThreadAssert();
    // TODO: forward when appropriate
}

- (CGFloat)yOffset {
    return self.offset.y;
}

- (void)setYOffset:(CGFloat)yOffset {
    MBMainThreadAssert();
    self.offset = CGPointMake(self.offset.x, yOffset);
}

- (CGFloat)xOffset {
    return self.offset.x;
}

- (void)setXOffset:(CGFloat)xOffset {
    MBMainThreadAssert();
    self.offset = CGPointMake(xOffset, self.offset.y);
}

- (CGFloat)cornerRadius {
    return self.bezelView.layer.cornerRadius;
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
    MBMainThreadAssert();
    self.bezelView.layer.cornerRadius = cornerRadius;
}

- (BOOL)dimBackground {
    // TODO: forward when appropriate
    return NO;
}

- (void)setDimBackground:(BOOL)dimBackground {
    MBMainThreadAssert();
    // TODO: forward when appropriate
}

- (CGSize)size {
    return self.bezelView.frame.size;
}

- (void)setActivityIndicatorColor:(UIColor *)activityIndicatorColor {
    if (activityIndicatorColor != _activityIndicatorColor) {
        _activityIndicatorColor = activityIndicatorColor;
        UIActivityIndicatorView *indicator = (UIActivityIndicatorView *)self.indicator;
        if ([indicator isKindOfClass:[UIActivityIndicatorView class]]) {
            [indicator setColor:activityIndicatorColor];
        }
    }
}

@end
