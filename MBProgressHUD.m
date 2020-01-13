//
// MBProgressHUD.m
// Version 1.2.0
// Created by Matej Bukovinski on 2.4.09.
//

#import "MBProgressHUD.h"
#import <tgmath.h>

#define MBMainThreadAssert() NSAssert([NSThread isMainThread], @"MBProgressHUD needs to be accessed on the main thread.");

CGFloat const MBProgressMaxOffset = 1000000.f;

static const CGFloat MBDefaultPadding = 4.f;
static const CGFloat MBDefaultLabelFontSize = 16.f;
static const CGFloat MBDefaultDetailsLabelFontSize = 12.f;


@interface MBProgressHUD ()

@property (nonatomic, assign) BOOL useAnimation;
@property (nonatomic, assign, getter=hasFinished) BOOL finished;
@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, strong) NSDate *showStarted;
@property (nonatomic, strong) NSArray *paddingConstraints;
@property (nonatomic, strong) NSArray *bezelConstraints;
@property (nonatomic, strong) UIView *topSpacer;
@property (nonatomic, strong) UIView *bottomSpacer;
@property (nonatomic, strong) UIMotionEffectGroup *bezelMotionEffects;
@property (nonatomic, weak) NSTimer *graceTimer;
@property (nonatomic, weak) NSTimer *minShowTimer;
@property (nonatomic, weak) NSTimer *hideDelayTimer;
@property (nonatomic, weak) CADisplayLink *progressObjectDisplayLink;

@end


@interface MBProgressHUDRoundedButton : UIButton
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
            MBProgressHUD *hud = (MBProgressHUD *)subview;
            if (hud.hasFinished == NO) {
                return hud;
            }
        }
    }
    return nil;
}

#pragma mark - Lifecycle

- (void)commonInit {
    // Set default values for properties
    _animationType = MBProgressHUDAnimationFade;
    _mode = MBProgressHUDModeIndeterminate;
    _margin = 20.0f;
    _defaultMotionEffectsEnabled = NO;

    if (@available(iOS 13.0, tvOS 13, *)) {
       _contentColor = [[UIColor labelColor] colorWithAlphaComponent:0.7f];
    } else {
        _contentColor = [UIColor colorWithWhite:0.f alpha:0.7f];
    }

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

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self commonInit];
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
    [self.minShowTimer invalidate];
    self.useAnimation = animated;
    self.finished = NO;
    // If the grace time is set, postpone the HUD display
    if (self.graceTime > 0.0) {
        NSTimer *timer = [NSTimer timerWithTimeInterval:self.graceTime target:self selector:@selector(handleGraceTimer:) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        self.graceTimer = timer;
    }
    // ... otherwise show the HUD immediately
    else {
        [self showUsingAnimation:self.useAnimation];
    }
}

- (void)hideAnimated:(BOOL)animated {
    MBMainThreadAssert();
    [self.graceTimer invalidate];
    self.useAnimation = animated;
    self.finished = YES;
    // If the minShow time is set, calculate how long the HUD was shown,
    // and postpone the hiding operation if necessary
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
    // Cancel any scheduled hideAnimated:afterDelay: calls
    [self.hideDelayTimer invalidate];

    NSTimer *timer = [NSTimer timerWithTimeInterval:delay target:self selector:@selector(handleHideTimer:) userInfo:@(animated) repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.hideDelayTimer = timer;
}

#pragma mark - Timer callbacks

- (void)handleGraceTimer:(NSTimer *)theTimer {
    // Show the HUD only if the task is still running
    if (!self.hasFinished) {
        [self showUsingAnimation:self.useAnimation];
    }
}

- (void)handleMinShowTimer:(NSTimer *)theTimer {
    [self hideUsingAnimation:self.useAnimation];
}

- (void)handleHideTimer:(NSTimer *)timer {
    [self hideAnimated:[timer.userInfo boolValue]];
}

#pragma mark - View Hierrarchy

- (void)didMoveToSuperview {
    [self updateForCurrentOrientationAnimated:NO];
}

#pragma mark - Internal show & hide operations

- (void)showUsingAnimation:(BOOL)animated {
    // Cancel any previous animations
    [self.bezelView.layer removeAllAnimations];
    [self.backgroundView.layer removeAllAnimations];

    // Cancel any scheduled hideAnimated:afterDelay: calls
    [self.hideDelayTimer invalidate];

    self.showStarted = [NSDate date];
    self.alpha = 1.f;

    // Needed in case we hide and re-show with the same NSProgress object attached.
    [self setNSProgressDisplayLinkEnabled:YES];

    // Set up motion effects only at this point to avoid needlessly
    // creating the effect if it was disabled after initialization.
    [self updateBezelMotionEffects];

    if (animated) {
        [self animateIn:YES withType:self.animationType completion:NULL];
    } else {
        self.bezelView.alpha = 1.f;
        self.backgroundView.alpha = 1.f;
    }
}

- (void)hideUsingAnimation:(BOOL)animated {
    // Cancel any scheduled hideAnimated:afterDelay: calls.
    // This needs to happen here instead of in done,
    // to avoid races if another hideAnimated:afterDelay:
    // call comes in while the HUD is animating out.
    [self.hideDelayTimer invalidate];

    if (animated && self.showStarted) {
        self.showStarted = nil;
        [self animateIn:NO withType:self.animationType completion:^(BOOL finished) {
            [self done];
        }];
    } else {
        self.showStarted = nil;
        self.bezelView.alpha = 0.f;
        self.backgroundView.alpha = 1.f;
        [self done];
    }
}

- (void)animateIn:(BOOL)animatingIn withType:(MBProgressHUDAnimation)type completion:(void(^)(BOOL finished))completion {
    // Automatically determine the correct zoom animation type
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
        CGFloat alpha = animatingIn ? 1.f : 0.f;
        bezelView.alpha = alpha;
        self.backgroundView.alpha = alpha;
    };
    [UIView animateWithDuration:0.3 delay:0. usingSpringWithDamping:1.f initialSpringVelocity:0.f options:UIViewAnimationOptionBeginFromCurrentState animations:animations completion:completion];
}

- (void)done {
    [self setNSProgressDisplayLinkEnabled:NO];

    if (self.hasFinished) {
        self.alpha = 0.0f;
        if (self.removeFromSuperViewOnHide) {
            [self removeFromSuperview];
        }
    }
    MBProgressHUDCompletionBlock completionBlock = self.completionBlock;
    if (completionBlock) {
        completionBlock();
    }
    id<MBProgressHUDDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(hudWasHidden:)]) {
        [delegate performSelector:@selector(hudWasHidden:) withObject:self];
    }
}

#pragma mark - UI

- (void)setupViews {
    UIColor *defaultColor = self.contentColor;

    MBBackgroundView *backgroundView = [[MBBackgroundView alloc] initWithFrame:self.bounds];
    backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    backgroundView.backgroundColor = [UIColor clearColor];
    backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backgroundView.alpha = 0.f;
    [self addSubview:backgroundView];
    _backgroundView = backgroundView;

    MBBackgroundView *bezelView = [MBBackgroundView new];
    bezelView.translatesAutoresizingMaskIntoConstraints = NO;
    bezelView.layer.cornerRadius = 5.f;
    bezelView.alpha = 0.f;
    [self addSubview:bezelView];
    _bezelView = bezelView;

    UILabel *label = [UILabel new];
    label.adjustsFontSizeToFitWidth = NO;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = defaultColor;
    label.font = [UIFont boldSystemFontOfSize:MBDefaultLabelFontSize];
    label.opaque = NO;
    label.backgroundColor = [UIColor clearColor];
    _label = label;

    UILabel *detailsLabel = [UILabel new];
    detailsLabel.adjustsFontSizeToFitWidth = NO;
    detailsLabel.textAlignment = NSTextAlignmentCenter;
    detailsLabel.textColor = defaultColor;
    detailsLabel.numberOfLines = 0;
    detailsLabel.font = [UIFont boldSystemFontOfSize:MBDefaultDetailsLabelFontSize];
    detailsLabel.opaque = NO;
    detailsLabel.backgroundColor = [UIColor clearColor];
    _detailsLabel = detailsLabel;

    UIButton *button = [MBProgressHUDRoundedButton buttonWithType:UIButtonTypeCustom];
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:MBDefaultDetailsLabelFontSize];
    [button setTitleColor:defaultColor forState:UIControlStateNormal];
    _button = button;

    for (UIView *view in @[label, detailsLabel, button]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [view setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisHorizontal];
        [view setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisVertical];
        [bezelView addSubview:view];
    }

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
            UIActivityIndicatorView *activityIndicator;
            [indicator removeFromSuperview];
#if !TARGET_OS_MACCATALYST
            if (@available(iOS 13.0, tvOS 13.0, *)) {
#endif
                activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
                activityIndicator.color = [UIColor whiteColor];
#if !TARGET_OS_MACCATALYST
            } else {
               activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            }
#endif
            [activityIndicator startAnimating];
            indicator = activityIndicator;
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

    [indicator setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisHorizontal];
    [indicator setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisVertical];

    [self updateViewsForColor:self.contentColor];
    [self setNeedsUpdateConstraints];
}

- (void)updateViewsForColor:(UIColor *)color {
    if (!color) return;

    self.label.textColor = color;
    self.detailsLabel.textColor = color;
    [self.button setTitleColor:color forState:UIControlStateNormal];

    // UIAppearance settings are prioritized. If they are preset the set color is ignored.

    UIView *indicator = self.indicator;
    if ([indicator isKindOfClass:[UIActivityIndicatorView class]]) {
        UIActivityIndicatorView *appearance = nil;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 90000
        appearance = [UIActivityIndicatorView appearanceWhenContainedIn:[MBProgressHUD class], nil];
#else
        // For iOS 9+
        appearance = [UIActivityIndicatorView appearanceWhenContainedInInstancesOfClasses:@[[MBProgressHUD class]]];
#endif

        if (appearance.color == nil) {
            ((UIActivityIndicatorView *)indicator).color = color;
        }
    } else if ([indicator isKindOfClass:[MBRoundProgressView class]]) {
        MBRoundProgressView *appearance = nil;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 90000
        appearance = [MBRoundProgressView appearanceWhenContainedIn:[MBProgressHUD class], nil];
#else
        appearance = [MBRoundProgressView appearanceWhenContainedInInstancesOfClasses:@[[MBProgressHUD class]]];
#endif
        if (appearance.progressTintColor == nil) {
            ((MBRoundProgressView *)indicator).progressTintColor = color;
        }
        if (appearance.backgroundTintColor == nil) {
            ((MBRoundProgressView *)indicator).backgroundTintColor = [color colorWithAlphaComponent:0.1];
        }
    } else if ([indicator isKindOfClass:[MBBarProgressView class]]) {
        MBBarProgressView *appearance = nil;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 90000
        appearance = [MBBarProgressView appearanceWhenContainedIn:[MBProgressHUD class], nil];
#else
        appearance = [MBBarProgressView appearanceWhenContainedInInstancesOfClasses:@[[MBProgressHUD class]]];
#endif
        if (appearance.progressColor == nil) {
            ((MBBarProgressView *)indicator).progressColor = color;
        }
        if (appearance.lineColor == nil) {
            ((MBBarProgressView *)indicator).lineColor = color;
        }
    } else {
        [indicator setTintColor:color];
    }
}

- (void)updateBezelMotionEffects {
    MBBackgroundView *bezelView = self.bezelView;
    UIMotionEffectGroup *bezelMotionEffects = self.bezelMotionEffects;

    if (self.defaultMotionEffectsEnabled && !bezelMotionEffects) {
        CGFloat effectOffset = 10.f;
        UIInterpolatingMotionEffect *effectX = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
        effectX.maximumRelativeValue = @(effectOffset);
        effectX.minimumRelativeValue = @(-effectOffset);

        UIInterpolatingMotionEffect *effectY = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
        effectY.maximumRelativeValue = @(effectOffset);
        effectY.minimumRelativeValue = @(-effectOffset);

        UIMotionEffectGroup *group = [[UIMotionEffectGroup alloc] init];
        group.motionEffects = @[effectX, effectY];

        self.bezelMotionEffects = group;
        [bezelView addMotionEffect:group];
    } else if (bezelMotionEffects) {
        self.bezelMotionEffects = nil;
        [bezelView removeMotionEffect:bezelMotionEffects];
    }
}

#pragma mark - Layout

- (void)updateConstraints {
    UIView *bezel = self.bezelView;
    UIView *topSpacer = self.topSpacer;
    UIView *bottomSpacer = self.bottomSpacer;
    CGFloat margin = self.margin;
    NSMutableArray *bezelConstraints = [NSMutableArray array];
    NSDictionary *metrics = @{@"margin": @(margin)};

    NSMutableArray *subviews = [NSMutableArray arrayWithObjects:self.topSpacer, self.label, self.detailsLabel, self.button, self.bottomSpacer, nil];
    if (self.indicator) [subviews insertObject:self.indicator atIndex:1];

    // Remove existing constraints
    [self removeConstraints:self.constraints];
    [topSpacer removeConstraints:topSpacer.constraints];
    [bottomSpacer removeConstraints:bottomSpacer.constraints];
    if (self.bezelConstraints) {
        [bezel removeConstraints:self.bezelConstraints];
        self.bezelConstraints = nil;
    }

    // Center bezel in container (self), applying the offset if set
    CGPoint offset = self.offset;
    NSMutableArray *centeringConstraints = [NSMutableArray array];
    [centeringConstraints addObject:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.f constant:offset.x]];
    [centeringConstraints addObject:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.f constant:offset.y]];
    [self applyPriority:998.f toConstraints:centeringConstraints];
    [self addConstraints:centeringConstraints];

    // Ensure minimum side margin is kept
    NSMutableArray *sideConstraints = [NSMutableArray array];
    [sideConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(>=margin)-[bezel]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(bezel)]];
    [sideConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=margin)-[bezel]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(bezel)]];
    [self applyPriority:999.f toConstraints:sideConstraints];
    [self addConstraints:sideConstraints];

    // Minimum bezel size, if set
    CGSize minimumSize = self.minSize;
    if (!CGSizeEqualToSize(minimumSize, CGSizeZero)) {
        NSMutableArray *minSizeConstraints = [NSMutableArray array];
        [minSizeConstraints addObject:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:minimumSize.width]];
        [minSizeConstraints addObject:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:minimumSize.height]];
        [self applyPriority:997.f toConstraints:minSizeConstraints];
        [bezelConstraints addObjectsFromArray:minSizeConstraints];
    }

    // Square aspect ratio, if set
    if (self.square) {
        NSLayoutConstraint *square = [NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeWidth multiplier:1.f constant:0];
        square.priority = 997.f;
        [bezelConstraints addObject:square];
    }

    // Top and bottom spacing
    [topSpacer addConstraint:[NSLayoutConstraint constraintWithItem:topSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:margin]];
    [bottomSpacer addConstraint:[NSLayoutConstraint constraintWithItem:bottomSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:margin]];
    // Top and bottom spaces should be equal
    [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:topSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:bottomSpacer attribute:NSLayoutAttributeHeight multiplier:1.f constant:0.f]];

    // Layout subviews in bezel
    NSMutableArray *paddingConstraints = [NSMutableArray new];
    [subviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        // Center in bezel
        [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeCenterX multiplier:1.f constant:0.f]];
        // Ensure the minimum edge margin is kept
        [bezelConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(>=margin)-[view]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(view)]];
        // Element spacing
        if (idx == 0) {
            // First, ensure spacing to bezel edge
            [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeTop multiplier:1.f constant:0.f]];
        } else if (idx == subviews.count - 1) {
            // Last, ensure spacing to bezel edge
            [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeBottom multiplier:1.f constant:0.f]];
        }
        if (idx > 0) {
            // Has previous
            NSLayoutConstraint *padding = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:subviews[idx - 1] attribute:NSLayoutAttributeBottom multiplier:1.f constant:0.f];
            [bezelConstraints addObject:padding];
            [paddingConstraints addObject:padding];
        }
    }];

    [bezel addConstraints:bezelConstraints];
    self.bezelConstraints = bezelConstraints;

    self.paddingConstraints = [paddingConstraints copy];
    [self updatePaddingConstraints];

    [super updateConstraints];
}

- (void)layoutSubviews {
    // There is no need to update constraints if they are going to
    // be recreated in [super layoutSubviews] due to needsUpdateConstraints being set.
    // This also avoids an issue on iOS 8, where updatePaddingConstraints
    // would trigger a zombie object access.
    if (!self.needsUpdateConstraints) {
        [self updatePaddingConstraints];
    }
    [super layoutSubviews];
}

- (void)updatePaddingConstraints {
    // Set padding dynamically, depending on whether the view is visible or not
    __block BOOL hasVisibleAncestors = NO;
    [self.paddingConstraints enumerateObjectsUsingBlock:^(NSLayoutConstraint *padding, NSUInteger idx, BOOL *stop) {
        UIView *firstView = (UIView *)padding.firstItem;
        UIView *secondView = (UIView *)padding.secondItem;
        BOOL firstVisible = !firstView.hidden && !CGSizeEqualToSize(firstView.intrinsicContentSize, CGSizeZero);
        BOOL secondVisible = !secondView.hidden && !CGSizeEqualToSize(secondView.intrinsicContentSize, CGSizeZero);
        // Set if both views are visible or if there's a visible view on top that doesn't have padding
        // added relative to the current view yet
        padding.constant = (firstVisible && (secondVisible || hasVisibleAncestors)) ? MBDefaultPadding : 0.f;
        hasVisibleAncestors |= secondVisible;
    }];
}

- (void)applyPriority:(UILayoutPriority)priority toConstraints:(NSArray *)constraints {
    for (NSLayoutConstraint *constraint in constraints) {
        constraint.priority = priority;
    }
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
    if (margin != _margin) {
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

- (void)setProgressObjectDisplayLink:(CADisplayLink *)progressObjectDisplayLink {
    if (progressObjectDisplayLink != _progressObjectDisplayLink) {
        [_progressObjectDisplayLink invalidate];

        _progressObjectDisplayLink = progressObjectDisplayLink;

        [_progressObjectDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

- (void)setProgressObject:(NSProgress *)progressObject {
    if (progressObject != _progressObject) {
        _progressObject = progressObject;
        [self setNSProgressDisplayLinkEnabled:YES];
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

- (void)setContentColor:(UIColor *)contentColor {
    if (contentColor != _contentColor && ![contentColor isEqual:_contentColor]) {
        _contentColor = contentColor;
        [self updateViewsForColor:contentColor];
    }
}

- (void)setDefaultMotionEffectsEnabled:(BOOL)defaultMotionEffectsEnabled {
    if (defaultMotionEffectsEnabled != _defaultMotionEffectsEnabled) {
        _defaultMotionEffectsEnabled = defaultMotionEffectsEnabled;
        [self updateBezelMotionEffects];
    }
}

#pragma mark - NSProgress

- (void)setNSProgressDisplayLinkEnabled:(BOOL)enabled {
    // We're using CADisplayLink, because NSProgress can change very quickly and observing it may starve the main thread,
    // so we're refreshing the progress only every frame draw
    if (enabled && self.progressObject) {
        // Only create if not already active.
        if (!self.progressObjectDisplayLink) {
            self.progressObjectDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateProgressFromProgressObject)];
        }
    } else {
        self.progressObjectDisplayLink = nil;
    }
}

- (void)updateProgressFromProgressObject {
    self.progress = self.progressObject.fractionCompleted;
}

#pragma mark - Notifications

- (void)registerForNotifications {
#if !TARGET_OS_TV && !TARGET_OS_MACCATALYST
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self selector:@selector(statusBarOrientationDidChange:)
               name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
#endif
}

- (void)unregisterFromNotifications {
#if !TARGET_OS_TV && !TARGET_OS_MACCATALYST
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
#endif
}

#if !TARGET_OS_TV && !TARGET_OS_MACCATALYST
- (void)statusBarOrientationDidChange:(NSNotification *)notification {
    UIView *superview = self.superview;
    if (!superview) {
        return;
    } else {
        [self updateForCurrentOrientationAnimated:YES];
    }
}
#endif

- (void)updateForCurrentOrientationAnimated:(BOOL)animated {
    // Stay in sync with the superview in any case
    if (self.superview) {
        self.frame = self.superview.bounds;
    }

    // Not needed on iOS 8+, compile out when the deployment target allows,
    // to avoid sharedApplication problems on extension targets
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 80000
    // Only needed pre iOS 8 when added to a window
    BOOL iOS8OrLater = kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0;
    if (iOS8OrLater || ![self.superview isKindOfClass:[UIWindow class]]) return;

    // Make extension friendly. Will not get called on extensions (iOS 8+) due to the above check.
    // This just ensures we don't get a warning about extension-unsafe API.
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if (!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) return;

    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    UIInterfaceOrientation orientation = application.statusBarOrientation;
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
    }
    return self;
}

#pragma mark - Layout

- (CGSize)intrinsicContentSize {
    return CGSizeMake(37.f, 37.f);
}

#pragma mark - Properties

- (void)setProgress:(float)progress {
    if (progress != _progress) {
        _progress = progress;
        [self setNeedsDisplay];
    }
}

- (void)setProgressTintColor:(UIColor *)progressTintColor {
    NSAssert(progressTintColor, @"The color should not be nil.");
    if (progressTintColor != _progressTintColor && ![progressTintColor isEqual:_progressTintColor]) {
        _progressTintColor = progressTintColor;
        [self setNeedsDisplay];
    }
}

- (void)setBackgroundTintColor:(UIColor *)backgroundTintColor {
    NSAssert(backgroundTintColor, @"The color should not be nil.");
    if (backgroundTintColor != _backgroundTintColor && ![backgroundTintColor isEqual:_backgroundTintColor]) {
        _backgroundTintColor = backgroundTintColor;
        [self setNeedsDisplay];
    }
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    if (_annular) {
        // Draw background
        CGFloat lineWidth = 2.f;
        UIBezierPath *processBackgroundPath = [UIBezierPath bezierPath];
        processBackgroundPath.lineWidth = lineWidth;
        processBackgroundPath.lineCapStyle = kCGLineCapButt;
        CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        CGFloat radius = (self.bounds.size.width - lineWidth)/2;
        CGFloat startAngle = - ((float)M_PI / 2); // 90 degrees
        CGFloat endAngle = (2 * (float)M_PI) + startAngle;
        [processBackgroundPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
        [_backgroundTintColor set];
        [processBackgroundPath stroke];
        // Draw progress
        UIBezierPath *processPath = [UIBezierPath bezierPath];
        processPath.lineCapStyle = kCGLineCapSquare;
        processPath.lineWidth = lineWidth;
        endAngle = (self.progress * 2 * (float)M_PI) + startAngle;
        [processPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
        [_progressTintColor set];
        [processPath stroke];
    } else {
        // Draw background
        CGFloat lineWidth = 2.f;
        CGRect allRect = self.bounds;
        CGRect circleRect = CGRectInset(allRect, lineWidth/2.f, lineWidth/2.f);
        CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        [_progressTintColor setStroke];
        [_backgroundTintColor setFill];
        CGContextSetLineWidth(context, lineWidth);
        CGContextStrokeEllipseInRect(context, circleRect);
        // 90 degrees
        CGFloat startAngle = - ((float)M_PI / 2.f);
        // Draw progress
        UIBezierPath *processPath = [UIBezierPath bezierPath];
        processPath.lineCapStyle = kCGLineCapButt;
        processPath.lineWidth = lineWidth * 2.f;
        CGFloat radius = (CGRectGetWidth(self.bounds) / 2.f) - (processPath.lineWidth / 2.f);
        CGFloat endAngle = (self.progress * 2.f * (float)M_PI) + startAngle;
        [processPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
        // Ensure that we don't get color overlapping when _progressTintColor alpha < 1.f.
        CGContextSetBlendMode(context, kCGBlendModeCopy);
        [_progressTintColor set];
        [processPath stroke];
    }
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
    }
    return self;
}

#pragma mark - Layout

- (CGSize)intrinsicContentSize {
    return CGSizeMake(120.f, 10.f);
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

    // Draw background and Border
    CGFloat radius = (rect.size.height / 2) - 2;
    CGContextMoveToPoint(context, 2, rect.size.height/2);
    CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius);
    CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius);
    CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius);
    CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height/2, radius);
    CGContextDrawPath(context, kCGPathFillStroke);

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


@interface MBBackgroundView ()

@property UIVisualEffectView *effectView;

@end


@implementation MBBackgroundView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _style = MBProgressHUDBackgroundStyleBlur;
        if (@available(iOS 13.0, *)) {
            #if TARGET_OS_TV
            _blurEffectStyle = UIBlurEffectStyleRegular;
            #else
            _blurEffectStyle = UIBlurEffectStyleSystemThickMaterial;
            #endif
            // Leaving the color unassigned yields best results.
        } else {
            _blurEffectStyle = UIBlurEffectStyleLight;
            _color = [UIColor colorWithWhite:0.8f alpha:0.6f];
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

- (void)setStyle:(MBProgressHUDBackgroundStyle)style {
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

- (void)setBlurEffectStyle:(UIBlurEffectStyle)blurEffectStyle {
    if (_blurEffectStyle == blurEffectStyle) {
        return;
    }

    _blurEffectStyle = blurEffectStyle;

    [self updateForBackgroundStyle];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Views

- (void)updateForBackgroundStyle {
    [self.effectView removeFromSuperview];
    self.effectView = nil;

    MBProgressHUDBackgroundStyle style = self.style;
    if (style == MBProgressHUDBackgroundStyleBlur) {
        UIBlurEffect *effect =  [UIBlurEffect effectWithStyle:self.blurEffectStyle];
        UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
        [self insertSubview:effectView atIndex:0];
        effectView.frame = self.bounds;
        effectView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = self.color;
        self.layer.allowsGroupOpacity = NO;
        self.effectView = effectView;
    } else {
        self.backgroundColor = self.color;
    }
}

- (void)updateViewsForColor:(UIColor *)color {
    if (self.style == MBProgressHUDBackgroundStyleBlur) {
        self.backgroundColor = self.color;
    } else {
        self.backgroundColor = self.color;
    }
}

@end


@implementation MBProgressHUDRoundedButton

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CALayer *layer = self.layer;
        layer.borderWidth = 1.f;
    }
    return self;
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    // Fully rounded corners
    CGFloat height = CGRectGetHeight(self.bounds);
    self.layer.cornerRadius = ceil(height / 2.f);
}

- (CGSize)intrinsicContentSize {
    // Only show if we have associated control events and a title
    if ((self.allControlEvents == 0) || ([self titleForState:UIControlStateNormal].length == 0))
		return CGSizeZero;
    CGSize size = [super intrinsicContentSize];
    // Add some side padding
    size.width += 20.f;
    return size;
}

#pragma mark - Color

- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state {
    [super setTitleColor:color forState:state];
    // Update related colors
    [self setHighlighted:self.highlighted];
    self.layer.borderColor = color.CGColor;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    UIColor *baseColor = [self titleColorForState:UIControlStateSelected];
    self.backgroundColor = highlighted ? [baseColor colorWithAlphaComponent:0.1f] : [UIColor clearColor];
}

@end
