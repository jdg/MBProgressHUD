//
// MBProgressHUD.m
// Version 0.8
// Created by Matej Bukovinski on 2.4.09.
//

#import "MBProgressHUD.h"
#import <tgmath.h>


#if __has_feature(objc_arc)
	#define MB_AUTORELEASE(exp) exp
	#define MB_RELEASE(exp) exp
	#define MB_RETAIN(exp) exp
#else
	#define MB_AUTORELEASE(exp) [exp autorelease]
	#define MB_RELEASE(exp) [exp release]
	#define MB_RETAIN(exp) [exp retain]
#endif

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
    #define MBLabelAlignmentCenter NSTextAlignmentCenter
#else
    #define MBLabelAlignmentCenter UITextAlignmentCenter
#endif

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
	#define MB_TEXTSIZE(text, font) [text length] > 0 ? [text \
		sizeWithAttributes:@{NSFontAttributeName:font}] : CGSizeZero;
#else
	#define MB_TEXTSIZE(text, font) [text length] > 0 ? [text sizeWithFont:font] : CGSizeZero;
#endif

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
	#define MB_MULTILINE_TEXTSIZE(text, font, maxSize, mode) [text length] > 0 ? [text \
		boundingRectWithSize:maxSize options:(NSStringDrawingUsesLineFragmentOrigin) \
		attributes:@{NSFontAttributeName:font} context:nil].size : CGSizeZero;
#else
	#define MB_MULTILINE_TEXTSIZE(text, font, maxSize, mode) [text length] > 0 ? [text \
		sizeWithFont:font constrainedToSize:maxSize lineBreakMode:mode] : CGSizeZero;
#endif


static const CGFloat kPadding = 4.f;
static const CGFloat kLabelFontSize = 16.f;
static const CGFloat kDetailsLabelFontSize = 12.f;


@interface MBProgressHUD ()

- (void)setupLabels;
- (void)registerForKVO;
- (void)unregisterFromKVO;
- (NSArray *)observableKeypaths;
- (void)registerForNotifications;
- (void)unregisterFromNotifications;
- (void)updateUIForKeypath:(NSString *)keyPath;
- (void)hideUsingAnimation:(BOOL)animated;
- (void)showUsingAnimation:(BOOL)animated;
- (void)done;
- (void)updateIndicators;
- (void)handleGraceTimer:(NSTimer *)theTimer;
- (void)handleMinShowTimer:(NSTimer *)theTimer;
- (void)setTransformForCurrentOrientation:(BOOL)animated;
- (void)cleanUp;
- (void)launchExecution;
- (void)deviceOrientationDidChange:(NSNotification *)notification;
- (void)hideDelayed:(NSNumber *)animated;

@property (atomic, MB_STRONG) UIView *indicator;
@property (atomic, MB_STRONG) NSTimer *graceTimer;
@property (atomic, MB_STRONG) NSTimer *minShowTimer;
@property (atomic, MB_STRONG) NSDate *showStarted;
@property (atomic, assign) CGSize size;
@property (atomic, MB_STRONG) MMBlurView *blurView;

@end


@implementation MBProgressHUD {
	BOOL useAnimation;
	SEL methodForExecution;
	id targetForExecution;
	id objectForExecution;
	UILabel *label;
	UILabel *detailsLabel;
	BOOL isFinished;
	CGAffineTransform rotationTransform;
}

#pragma mark - Properties

@synthesize animationType;
@synthesize delegate;
@synthesize opacity;
@synthesize color;
@synthesize labelFont;
@synthesize labelColor;
@synthesize detailsLabelFont;
@synthesize detailsLabelColor;
@synthesize indicator;
@synthesize xOffset;
@synthesize yOffset;
@synthesize minSize;
@synthesize square;
@synthesize margin;
@synthesize dimBackground;
@synthesize graceTime;
@synthesize minShowTime;
@synthesize graceTimer;
@synthesize minShowTimer;
@synthesize taskInProgress;
@synthesize removeFromSuperViewOnHide;
@synthesize customView;
@synthesize showStarted;
@synthesize mode;
@synthesize labelText;
@synthesize detailsLabelText;
@synthesize progress;
@synthesize size;
#if NS_BLOCKS_AVAILABLE
@synthesize completionBlock;
#endif

#pragma mark - Class methods

+ (MB_INSTANCETYPE)showHUDAddedTo:(UIView *)view animated:(BOOL)animated {
	MBProgressHUD *hud = [[self alloc] initWithView:view];
	[view addSubview:hud];
	[hud show:animated];
	return MB_AUTORELEASE(hud);
}

+ (BOOL)hideHUDForView:(UIView *)view animated:(BOOL)animated {
	MBProgressHUD *hud = [self HUDForView:view];
	if (hud != nil) {
		hud.removeFromSuperViewOnHide = YES;
		[hud hide:animated];
		return YES;
	}
	return NO;
}

+ (NSUInteger)hideAllHUDsForView:(UIView *)view animated:(BOOL)animated {
	NSArray *huds = [MBProgressHUD allHUDsForView:view];
	for (MBProgressHUD *hud in huds) {
		hud.removeFromSuperViewOnHide = YES;
		[hud hide:animated];
	}
	return [huds count];
}

+ (MB_INSTANCETYPE)HUDForView:(UIView *)view {
	NSEnumerator *subviewsEnum = [view.subviews reverseObjectEnumerator];
	for (UIView *subview in subviewsEnum) {
		if ([subview isKindOfClass:self]) {
			return (MBProgressHUD *)subview;
		}
	}
	return nil;
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

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		// Set default values for properties
		self.animationType = MBProgressHUDAnimationFade;
		self.mode = MBProgressHUDModeIndeterminate;
		self.labelText = nil;
		self.detailsLabelText = nil;
		self.opacity = 0.8f;
        self.color = nil;
		self.labelFont = [UIFont boldSystemFontOfSize:kLabelFontSize];
        self.labelColor = [UIColor whiteColor];
		self.detailsLabelFont = [UIFont boldSystemFontOfSize:kDetailsLabelFontSize];
        self.detailsLabelColor = [UIColor whiteColor];
		self.xOffset = 0.0f;
		self.yOffset = 0.0f;
		self.dimBackground = NO;
		self.margin = 20.0f;
        self.cornerRadius = 10.0f;
		self.graceTime = 0.0f;
		self.minShowTime = 0.0f;
		self.removeFromSuperViewOnHide = NO;
		self.minSize = CGSizeZero;
		self.square = NO;
        //Only support iOS7 above now
        self.blur = iOS_7_Above;
		self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin 
								| UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

		// Transparent background
		self.opaque = NO;
		self.backgroundColor = [UIColor clearColor];
		// Make it invisible for now
		self.alpha = 0.0f;
		
		taskInProgress = NO;
		rotationTransform = CGAffineTransformIdentity;
        
        self.layer.shadowOffset = CGSizeMake(0, 0);
        self.layer.shadowColor = [[UIColor blackColor] CGColor];
        self.layer.shadowOpacity = 0.75f;
        self.layer.shadowRadius = 1.0;
		
		[self setupLabels];
		[self updateIndicators];
		[self registerForKVO];
		[self registerForNotifications];
	}
	return self;
}

- (void)setBlur:(BOOL)blur{
    _blur = blur&&iOS_7_Above;
}

- (id)initWithView:(UIView *)view {
	NSAssert(view, @"View must not be nil.");
	return [self initWithFrame:view.bounds];
}

- (id)initWithWindow:(UIWindow *)window {
	return [self initWithView:window];
}

- (void)dealloc {
	[self unregisterFromNotifications];
	[self unregisterFromKVO];
    self.blurView = nil;
#if !__has_feature(objc_arc)
	[color release];
	[indicator release];
	[label release];
	[detailsLabel release];
	[labelText release];
	[detailsLabelText release];
	[graceTimer release];
	[minShowTimer release];
	[showStarted release];
	[customView release];
#if NS_BLOCKS_AVAILABLE
	[completionBlock release];
#endif
	[super dealloc];
#endif
}

#pragma mark - Show & hide

- (void)show:(BOOL)animated {
	useAnimation = animated;
	// If the grace time is set postpone the HUD display
	if (self.graceTime > 0.0) {
		self.graceTimer = [NSTimer scheduledTimerWithTimeInterval:self.graceTime target:self 
						   selector:@selector(handleGraceTimer:) userInfo:nil repeats:NO];
	} 
	// ... otherwise show the HUD imediately 
	else {
		[self setNeedsDisplay];
		[self showUsingAnimation:useAnimation];
	}
}

- (void)hide:(BOOL)animated {
	useAnimation = animated;
	// If the minShow time is set, calculate how long the hud was shown,
	// and pospone the hiding operation if necessary
	if (self.minShowTime > 0.0 && showStarted) {
		NSTimeInterval interv = [[NSDate date] timeIntervalSinceDate:showStarted];
		if (interv < self.minShowTime) {
			self.minShowTimer = [NSTimer scheduledTimerWithTimeInterval:(self.minShowTime - interv) target:self 
								selector:@selector(handleMinShowTimer:) userInfo:nil repeats:NO];
			return;
		} 
	}
	// ... otherwise hide the HUD immediately
	[self hideUsingAnimation:useAnimation];
}

- (void)hide:(BOOL)animated afterDelay:(NSTimeInterval)delay {
	[self performSelector:@selector(hideDelayed:) withObject:[NSNumber numberWithBool:animated] afterDelay:delay];
}

- (void)hideDelayed:(NSNumber *)animated {
	[self hide:[animated boolValue]];
}

#pragma mark - Timer callbacks

- (void)handleGraceTimer:(NSTimer *)theTimer {
	// Show the HUD only if the task is still running
	if (taskInProgress) {
		[self setNeedsDisplay];
		[self showUsingAnimation:useAnimation];
	}
}

- (void)handleMinShowTimer:(NSTimer *)theTimer {
	[self hideUsingAnimation:useAnimation];
}

#pragma mark - View Hierrarchy

- (void)didMoveToSuperview {
	// We need to take care of rotation ourselfs if we're adding the HUD to a window
	if ([self.superview isKindOfClass:[UIWindow class]]) {
		[self setTransformForCurrentOrientation:NO];
	}
}

#pragma mark - Internal show & hide operations

- (void)showUsingAnimation:(BOOL)animated {
	if (animated && animationType == MBProgressHUDAnimationZoomIn) {
		self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(0.5f, 0.5f));
	} else if (animated && animationType == MBProgressHUDAnimationZoomOut) {
		self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(1.5f, 1.5f));
	}
	self.showStarted = [NSDate date];
	// Fade in
	if (animated) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.30];
		self.alpha = 1.0f;
		if (animationType == MBProgressHUDAnimationZoomIn || animationType == MBProgressHUDAnimationZoomOut) {
			self.transform = rotationTransform;
		}
		[UIView commitAnimations];
	}
	else {
		self.alpha = 1.0f;
	}
}

- (void)hideUsingAnimation:(BOOL)animated {
	// Fade out
	if (animated && showStarted) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.30];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(animationFinished:finished:context:)];
		// 0.02 prevents the hud from passing through touches during the animation the hud will get completely hidden
		// in the done method
		if (animationType == MBProgressHUDAnimationZoomIn) {
			self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(1.5f, 1.5f));
		} else if (animationType == MBProgressHUDAnimationZoomOut) {
			self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(0.5f, 0.5f));
		}

		self.alpha = 0.02f;
		[UIView commitAnimations];
	}
	else {
		self.alpha = 0.0f;
		[self done];
	}
	self.showStarted = nil;
}

- (void)animationFinished:(NSString *)animationID finished:(BOOL)finished context:(void*)context {
	[self done];
}

- (void)done {
	isFinished = YES;
	self.alpha = 0.0f;
	if (removeFromSuperViewOnHide) {
		[self removeFromSuperview];
	}
#if NS_BLOCKS_AVAILABLE
	if (self.completionBlock) {
		self.completionBlock();
		self.completionBlock = NULL;
	}
#endif
	if ([delegate respondsToSelector:@selector(hudWasHidden:)]) {
		[delegate performSelector:@selector(hudWasHidden:) withObject:self];
	}
}

#pragma mark - Threading

- (void)showWhileExecuting:(SEL)method onTarget:(id)target withObject:(id)object animated:(BOOL)animated {
	methodForExecution = method;
	targetForExecution = MB_RETAIN(target);
	objectForExecution = MB_RETAIN(object);	
	// Launch execution in new thread
	self.taskInProgress = YES;
	[NSThread detachNewThreadSelector:@selector(launchExecution) toTarget:self withObject:nil];
	// Show HUD view
	[self show:animated];
}

#if NS_BLOCKS_AVAILABLE

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
  [self show:animated];
}

#endif

- (void)launchExecution {
	@autoreleasepool {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		// Start executing the requested task
		[targetForExecution performSelector:methodForExecution withObject:objectForExecution];
#pragma clang diagnostic pop
		// Task completed, update view in main thread (note: view operations should
		// be done only in the main thread)
		[self performSelectorOnMainThread:@selector(cleanUp) withObject:nil waitUntilDone:NO];
	}
}

- (void)cleanUp {
	taskInProgress = NO;
#if !__has_feature(objc_arc)
	[targetForExecution release];
	[objectForExecution release];
#else
	targetForExecution = nil;
	objectForExecution = nil;
#endif
	[self hide:useAnimation];
}

#pragma mark - UI

- (void)setupLabels {
	label = [[UILabel alloc] initWithFrame:self.bounds];
	label.adjustsFontSizeToFitWidth = NO;
	label.textAlignment = MBLabelAlignmentCenter;
	label.opaque = NO;
	label.backgroundColor = [UIColor clearColor];
	label.textColor = self.labelColor;
	label.font = self.labelFont;
	label.text = self.labelText;
    label.layer.shadowOffset = CGSizeMake(0, 0);
    label.layer.shadowColor = [[UIColor blackColor] CGColor];
    label.layer.shadowRadius = 1.0;
    label.layer.shadowOpacity = 0.75;
	[self addSubview:label];
	
	detailsLabel = [[UILabel alloc] initWithFrame:self.bounds];
	detailsLabel.font = self.detailsLabelFont;
	detailsLabel.adjustsFontSizeToFitWidth = NO;
	detailsLabel.textAlignment = MBLabelAlignmentCenter;
	detailsLabel.opaque = NO;
	detailsLabel.backgroundColor = [UIColor clearColor];
	detailsLabel.textColor = self.detailsLabelColor;
	detailsLabel.numberOfLines = 0;
	detailsLabel.font = self.detailsLabelFont;
	detailsLabel.text = self.detailsLabelText;
    detailsLabel.layer.shadowOffset = CGSizeMake(0, 0);
    detailsLabel.layer.shadowColor = [[UIColor blackColor] CGColor];
    detailsLabel.layer.shadowRadius = 1.0;
    detailsLabel.layer.shadowOpacity = 0.75;
	[self addSubview:detailsLabel];
}

- (void)updateIndicators {
	
	BOOL isActivityIndicator = [indicator isKindOfClass:[UIActivityIndicatorView class]];
	BOOL isRoundIndicator = [indicator isKindOfClass:[MBRoundProgressView class]];
	
	if (mode == MBProgressHUDModeIndeterminate &&  !isActivityIndicator) {
		// Update to indeterminate indicator
		[indicator removeFromSuperview];
		self.indicator = MB_AUTORELEASE([[UIActivityIndicatorView alloc]
										 initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge]);
		[(UIActivityIndicatorView *)indicator startAnimating];
		[self addSubview:indicator];
	}
	else if (mode == MBProgressHUDModeDeterminateHorizontalBar) {
		// Update to bar determinate indicator
		[indicator removeFromSuperview];
        self.indicator = MB_AUTORELEASE([[MBBarProgressView alloc] init]);
		[self addSubview:indicator];
	}
	else if (mode == MBProgressHUDModeDeterminate || mode == MBProgressHUDModeAnnularDeterminate) {
		if (!isRoundIndicator) {
			// Update to determinante indicator
			[indicator removeFromSuperview];
			self.indicator = MB_AUTORELEASE([[MBRoundProgressView alloc] init]);
			[self addSubview:indicator];
		}
		if (mode == MBProgressHUDModeAnnularDeterminate) {
			[(MBRoundProgressView *)indicator setAnnular:YES];
		}
	} 
	else if (mode == MBProgressHUDModeCustomView && customView != indicator) {
		// Update custom view indicator
		[indicator removeFromSuperview];
		self.indicator = customView;
		[self addSubview:indicator];
	} else if (mode == MBProgressHUDModeText) {
		[indicator removeFromSuperview];
		self.indicator = nil;
	}
}

#pragma mark - Layout

- (void)layoutSubviews {
	
	// Entirely cover the parent view
	UIView *parent = self.superview;
	if (parent) {
		self.frame = parent.bounds;
	}
	CGRect bounds = self.bounds;
	
	// Determine the total widt and height needed
	CGFloat maxWidth = bounds.size.width - 4 * margin;
	CGSize totalSize = CGSizeZero;
	
	CGRect indicatorF = indicator.bounds;
	indicatorF.size.width = MIN(indicatorF.size.width, maxWidth);
	totalSize.width = MAX(totalSize.width, indicatorF.size.width);
	totalSize.height += indicatorF.size.height;
	
	CGSize labelSize = MB_TEXTSIZE(label.text, label.font);
	labelSize.width = MIN(labelSize.width, maxWidth);
	totalSize.width = MAX(totalSize.width, labelSize.width);
	totalSize.height += labelSize.height;
	if (labelSize.height > 0.f && indicatorF.size.height > 0.f) {
		totalSize.height += kPadding;
	}

	CGFloat remainingHeight = bounds.size.height - totalSize.height - kPadding - 4 * margin; 
	CGSize maxSize = CGSizeMake(maxWidth, remainingHeight);
	CGSize detailsLabelSize = MB_MULTILINE_TEXTSIZE(detailsLabel.text, detailsLabel.font, maxSize, detailsLabel.lineBreakMode);
	totalSize.width = MAX(totalSize.width, detailsLabelSize.width);
	totalSize.height += detailsLabelSize.height;
	if (detailsLabelSize.height > 0.f && (indicatorF.size.height > 0.f || labelSize.height > 0.f)) {
		totalSize.height += kPadding;
	}
	
	totalSize.width += 2 * margin;
	totalSize.height += 2 * margin;
	
	// Position elements
	CGFloat yPos = round(((bounds.size.height - totalSize.height) / 2)) + margin + yOffset;
	CGFloat xPos = xOffset;
	indicatorF.origin.y = yPos;
	indicatorF.origin.x = round((bounds.size.width - indicatorF.size.width) / 2) + xPos;
	indicator.frame = indicatorF;
	yPos += indicatorF.size.height;
	
	if (labelSize.height > 0.f && indicatorF.size.height > 0.f) {
		yPos += kPadding;
	}
	CGRect labelF;
	labelF.origin.y = yPos;
	labelF.origin.x = round((bounds.size.width - labelSize.width) / 2) + xPos;
	labelF.size = labelSize;
	label.frame = labelF;
	yPos += labelF.size.height;
	
	if (detailsLabelSize.height > 0.f && (indicatorF.size.height > 0.f || labelSize.height > 0.f)) {
		yPos += kPadding;
	}
	CGRect detailsLabelF;
	detailsLabelF.origin.y = yPos;
	detailsLabelF.origin.x = round((bounds.size.width - detailsLabelSize.width) / 2) + xPos;
	detailsLabelF.size = detailsLabelSize;
	detailsLabel.frame = detailsLabelF;
	
	// Enforce minsize and quare rules
	if (square) {
		CGFloat max = MAX(totalSize.width, totalSize.height);
		if (max <= bounds.size.width - 2 * margin) {
			totalSize.width = max;
		}
		if (max <= bounds.size.height - 2 * margin) {
			totalSize.height = max;
		}
	}
	if (totalSize.width < minSize.width) {
		totalSize.width = minSize.width;
	} 
	if (totalSize.height < minSize.height) {
		totalSize.height = minSize.height;
	}
	
	self.size = totalSize;
}

#pragma mark BG Drawing

- (void)drawRect:(CGRect)rect {
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	UIGraphicsPushContext(context);

	if (self.dimBackground) {
		//Gradient colours
		size_t gradLocationsNum = 2;
		CGFloat gradLocations[2] = {0.0f, 1.0f};
		CGFloat gradColors[8] = {0.0f,0.0f,0.0f,0.0f,0.0f,0.0f,0.0f,0.75f}; 
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, gradColors, gradLocations, gradLocationsNum);
		CGColorSpaceRelease(colorSpace);
		//Gradient center
		CGPoint gradCenter= CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
		//Gradient radius
		float gradRadius = MIN(self.bounds.size.width , self.bounds.size.height) ;
		//Gradient draw
		CGContextDrawRadialGradient (context, gradient, gradCenter,
									 0, gradCenter, gradRadius,
									 kCGGradientDrawsAfterEndLocation);
		CGGradientRelease(gradient);
	}

    // Set background rect color
    if(self.blur){
        CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    }else{
        if (self.color) {
            CGContextSetFillColorWithColor(context, self.color.CGColor);
        } else {
            CGContextSetGrayFillColor(context, 0.0f, self.opacity);
        }
    }

	
	// Center HUD
	CGRect allRect = self.bounds;
	// Draw rounded HUD backgroud rect
	CGRect boxRect = CGRectMake(round((allRect.size.width - size.width) / 2) + self.xOffset,
								round((allRect.size.height - size.height) / 2) + self.yOffset, size.width, size.height);
    
    //set the blur view
    if(self.blur){
        if(!self.blurView){
            self.blurView = [MMBlurView loadWithLocation:boxRect.origin parent:self.superview frame:boxRect];
            [self addSubview:self.blurView];
            [self sendSubviewToBack:self.blurView];
        }
        CGRect frame = self.blurView.frame;
        frame.origin = boxRect.origin;
        self.blurView.frame = frame;
        if(self.darkBlur)
            [self.blurView blurWithColor:[MMBlurComponents darkEffect]];
        else
            [self.blurView blurWithColor:[MMBlurComponents lightEffect]];
    }else{
        if(self.blurView){
            [self.blurView removeFromSuperview];
            self.blurView = nil;
        }
    }
    
	float radius = self.cornerRadius;
	CGContextBeginPath(context);
	CGContextMoveToPoint(context, CGRectGetMinX(boxRect) + radius, CGRectGetMinY(boxRect));
	CGContextAddArc(context, CGRectGetMaxX(boxRect) - radius, CGRectGetMinY(boxRect) + radius, radius, 3 * (float)M_PI / 2, 0, 0);
	CGContextAddArc(context, CGRectGetMaxX(boxRect) - radius, CGRectGetMaxY(boxRect) - radius, radius, 0, (float)M_PI / 2, 0);
	CGContextAddArc(context, CGRectGetMinX(boxRect) + radius, CGRectGetMaxY(boxRect) - radius, radius, (float)M_PI / 2, (float)M_PI, 0);
	CGContextAddArc(context, CGRectGetMinX(boxRect) + radius, CGRectGetMinY(boxRect) + radius, radius, (float)M_PI, 3 * (float)M_PI / 2, 0);
	CGContextClosePath(context);
	CGContextFillPath(context);

	UIGraphicsPopContext();
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
	return [NSArray arrayWithObjects:@"mode", @"customView", @"labelText", @"labelFont", @"labelColor",
			@"detailsLabelText", @"detailsLabelFont", @"detailsLabelColor", @"progress", nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:@selector(updateUIForKeypath:) withObject:keyPath waitUntilDone:NO];
	} else {
		[self updateUIForKeypath:keyPath];
	}
}

- (void)updateUIForKeypath:(NSString *)keyPath {
	if ([keyPath isEqualToString:@"mode"] || [keyPath isEqualToString:@"customView"]) {
		[self updateIndicators];
	} else if ([keyPath isEqualToString:@"labelText"]) {
		label.text = self.labelText;
	} else if ([keyPath isEqualToString:@"labelFont"]) {
		label.font = self.labelFont;
	} else if ([keyPath isEqualToString:@"labelColor"]) {
		label.textColor = self.labelColor;
	} else if ([keyPath isEqualToString:@"detailsLabelText"]) {
		detailsLabel.text = self.detailsLabelText;
	} else if ([keyPath isEqualToString:@"detailsLabelFont"]) {
		detailsLabel.font = self.detailsLabelFont;
	} else if ([keyPath isEqualToString:@"detailsLabelColor"]) {
		detailsLabel.textColor = self.detailsLabelColor;
	} else if ([keyPath isEqualToString:@"progress"]) {
		if ([indicator respondsToSelector:@selector(setProgress:)]) {
			[(id)indicator setProgress:progress];
		}
		return;
	}
	[self setNeedsLayout];
	[self setNeedsDisplay];
}

#pragma mark - Notifications

- (void)registerForNotifications {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(deviceOrientationDidChange:) 
			   name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)unregisterFromNotifications {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)deviceOrientationDidChange:(NSNotification *)notification { 
	UIView *superview = self.superview;
	if (!superview) {
		return;
	} else if ([superview isKindOfClass:[UIWindow class]]) {
		[self setTransformForCurrentOrientation:YES];
	} else {
		self.frame = self.superview.bounds;
		[self setNeedsDisplay];
	}
}

- (void)setTransformForCurrentOrientation:(BOOL)animated {	
	// Stay in sync with the superview
	if (self.superview) {
		self.bounds = self.superview.bounds;
		[self setNeedsDisplay];
	}
	
	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	CGFloat radians = 0;
	if (UIInterfaceOrientationIsLandscape(orientation)) {
		if (orientation == UIInterfaceOrientationLandscapeLeft) { radians = -(CGFloat)M_PI_2; } 
		else { radians = (CGFloat)M_PI_2; }
		// Window coordinates differ!
		self.bounds = CGRectMake(0, 0, self.bounds.size.height, self.bounds.size.width);
	} else {
		if (orientation == UIInterfaceOrientationPortraitUpsideDown) { radians = (CGFloat)M_PI; } 
		else { radians = 0; }
	}
	rotationTransform = CGAffineTransformMakeRotation(radians);
	
	if (animated) {
		[UIView beginAnimations:nil context:nil];
	}
	[self setTransform:rotationTransform];
	if (animated) {
		[UIView commitAnimations];
	}
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
        
        self.layer.shadowOffset = CGSizeMake(0, 0);
        self.layer.shadowColor = [[UIColor blackColor] CGColor];
        self.layer.shadowOpacity = 0.75f;
        self.layer.shadowRadius = 1.0;

	}
	return self;
}

- (void)dealloc {
	[self unregisterFromKVO];
#if !__has_feature(objc_arc)
	[_progressTintColor release];
	[_backgroundTintColor release];
	[super dealloc];
#endif
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
	
	CGRect allRect = self.bounds;
	CGRect circleRect = CGRectInset(allRect, 2.0f, 2.0f);
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	if (_annular) {
		// Draw background
		CGFloat lineWidth = 5.f;
		UIBezierPath *processBackgroundPath = [UIBezierPath bezierPath];
		processBackgroundPath.lineWidth = lineWidth;
		processBackgroundPath.lineCapStyle = kCGLineCapRound;
		CGPoint center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
		CGFloat radius = (self.bounds.size.width - lineWidth)/2;
		CGFloat startAngle = - ((float)M_PI / 2); // 90 degrees
		CGFloat endAngle = (2 * (float)M_PI) + startAngle;
		[processBackgroundPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
		[_backgroundTintColor set];
		[processBackgroundPath stroke];
		// Draw progress
		UIBezierPath *processPath = [UIBezierPath bezierPath];
		processPath.lineCapStyle = kCGLineCapRound;
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
		CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f); // white
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
        self.layer.shadowOffset = CGSizeMake(0, 0);
        self.layer.shadowColor = [[UIColor blackColor] CGColor];
        self.layer.shadowOpacity = 0.75f;
        self.layer.shadowRadius = 1.0;
		[self registerForKVO];
    }
    return self;
}

- (void)dealloc {
	[self unregisterFromKVO];
#if !__has_feature(objc_arc)
	[_lineColor release];
	[_progressColor release];
	[_progressRemainingColor release];
	[super dealloc];
#endif
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	// setup properties
	CGContextSetLineWidth(context, 2);
	CGContextSetStrokeColorWithColor(context,[_lineColor CGColor]);
	CGContextSetFillColorWithColor(context, [_progressRemainingColor CGColor]);
	
	// draw line border
	float radius = (rect.size.height / 2) - 2;
	CGContextMoveToPoint(context, 2, rect.size.height/2);
	CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius);
	CGContextAddLineToPoint(context, rect.size.width - radius - 2, 2);
	CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius);
	CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius);
	CGContextAddLineToPoint(context, radius + 2, rect.size.height - 2);
	CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height/2, radius);
	CGContextFillPath(context);
	
	// draw progress background
	CGContextMoveToPoint(context, 2, rect.size.height/2);
	CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius);
	CGContextAddLineToPoint(context, rect.size.width - radius - 2, 2);
	CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius);
	CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius);
	CGContextAddLineToPoint(context, radius + 2, rect.size.height - 2);
	CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height/2, radius);
	CGContextStrokePath(context);
	
	// setup to draw progress color
	CGContextSetFillColorWithColor(context, [_progressColor CGColor]);
	radius = radius - 2;
	float amount = self.progress * rect.size.width;
	
	// if progress is in the middle area
	if (amount >= radius + 4 && amount <= (rect.size.width - radius - 4)) {
		// top
		CGContextMoveToPoint(context, 4, rect.size.height/2);
		CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
		CGContextAddLineToPoint(context, amount, 4);
		CGContextAddLineToPoint(context, amount, radius + 4);
		
		// bottom
		CGContextMoveToPoint(context, 4, rect.size.height/2);
		CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
		CGContextAddLineToPoint(context, amount, rect.size.height - 4);
		CGContextAddLineToPoint(context, amount, radius + 4);
		
		CGContextFillPath(context);
	}
	
	// progress is in the right arc
	else if (amount > radius + 4) {
		float x = amount - (rect.size.width - radius - 4);
		
		// top
		CGContextMoveToPoint(context, 4, rect.size.height/2);
		CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
		CGContextAddLineToPoint(context, rect.size.width - radius - 4, 4);
		float angle = -acos(x/radius);
		if (isnan(angle)) angle = 0;
		CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height/2, radius, M_PI, angle, 0);
		CGContextAddLineToPoint(context, amount, rect.size.height/2);
		
		// bottom
		CGContextMoveToPoint(context, 4, rect.size.height/2);
		CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
		CGContextAddLineToPoint(context, rect.size.width - radius - 4, rect.size.height - 4);
		angle = acos(x/radius);
		if (isnan(angle)) angle = 0;
		CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height/2, radius, -M_PI, angle, 1);
		CGContextAddLineToPoint(context, amount, rect.size.height/2);
		
		CGContextFillPath(context);
	}
	
	// progress is in the left arc
	else if (amount < radius + 4 && amount > 0) {
		// top
		CGContextMoveToPoint(context, 4, rect.size.height/2);
		CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
		CGContextAddLineToPoint(context, radius + 4, rect.size.height/2);
		
		// bottom
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


@interface MMBlurView ()

@property(nonatomic, MB_WEAK) UIView *parent;
@property(nonatomic, MB_WEAK) CGPoint location;
@property(nonatomic, MB_WEAK) MMBlurType blurType;
@property(nonatomic, MB_STRONG) MMBlurComponents *colorComponents;
@property(nonatomic, MB_STRONG) UIImageView *backgroundImageView;
@property(nonatomic, MB_WEAK) dispatch_source_t timer;
//Property with retain or strong attribute must be of object type
@end

@implementation MMBlurView

- (void)dealloc{
    self.backgroundImageView = nil;
    self.colorComponents = nil;
#if !__has_feature(objc_arc)
	[super dealloc];
#endif
}

+ (MMBlurView *) load:(UIView *) view {
    MMBlurView *blur = MB_AUTORELEASE([[MMBlurView alloc]initWithFrame:CGRectZero]);
    blur.parent = view;
    blur.location = CGPointMake(0, 64);
    blur.frame = CGRectMake(blur.location.x, -(blur.frame.size.height + blur.location.y), blur.frame.size.width, blur.frame.size.height);
    
    return blur;
}

+ (MMBlurView *) loadWithLocation:(CGPoint) point parent:(UIView *) view {
    MMBlurView *blur = MB_AUTORELEASE([[MMBlurView alloc]initWithFrame:CGRectZero]);
    blur.parent = view;
    blur.location = point;
    blur.frame = CGRectMake(0, 0, blur.frame.size.width, blur.frame.size.height);
    return blur;
}

+ (MMBlurView *) loadWithLocation:(CGPoint) point parent:(UIView *) view frame:(CGRect)frame{
    MMBlurView *blur = MB_AUTORELEASE([[MMBlurView alloc]initWithFrame:frame]);
    blur.parent = view;
    blur.location = point;
    return blur;
}

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if(self){
        _backgroundImageView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        [self addSubview:self.backgroundImageView];
        self.backgroundImageView.layer.cornerRadius = 10.0;
        self.backgroundImageView.clipsToBounds = YES;
        self.backgroundImageView.layer.masksToBounds = YES;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setFrame:(CGRect)frame{
    [super setFrame:frame];
    self.backgroundImageView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
}

- (void) unload {
    if(self.timer != nil) {
        
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
    [self removeFromSuperview];
}

- (void) blurBackground {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(CGRectGetWidth(self.parent.frame), CGRectGetHeight(self.parent.frame)), NO, 1);
    
    //Snapshot finished in 0.051982 seconds.
    [self.parent drawViewHierarchyInRect:CGRectMake(0, 0, CGRectGetWidth(self.parent.frame), CGRectGetHeight(self.parent.frame)) afterScreenUpdates:NO];
    
    __block UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //Blur finished in 0.004884 seconds.
        snapshot = [snapshot applyBlurWithCrop:CGRectMake(self.location.x, self.location.y, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame)) resize:CGSizeMake(CGRectGetWidth(self.frame), CGRectGetHeight(self.frame)) blurRadius:self.colorComponents.radius tintColor:self.colorComponents.tintColor saturationDeltaFactor:self.colorComponents.saturationDeltaFactor maskImage:self.colorComponents.maskImage];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.backgroundImageView.image = snapshot;
        });
    });
}

- (void) blurWithColor:(MMBlurComponents *) components {
    if(self.blurType == MMBlurUndefined) {
        self.blurType = MMStaticBlur;
        self.colorComponents = components;
    }
    
    [self blurBackground];
}

- (void) blurWithColor:(MMBlurComponents *) components updateInterval:(float) interval {
    self.blurType = MMLiveBlur;
    self.colorComponents = components;
    
    self.timer = DispatchTimer(interval * NSEC_PER_SEC, 1ull * NSEC_PER_SEC, dispatch_get_main_queue(), ^{[self blurWithColor:components];});
}

dispatch_source_t DispatchTimer(uint64_t interval, uint64_t leeway, dispatch_queue_t queue, dispatch_block_t block) {
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    if (timer) {
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), interval, leeway);
        dispatch_source_set_event_handler(timer, block);
        
        dispatch_resume(timer);
    }
    
    return timer;
}

@end

@implementation MMBlurComponents

- (void)dealloc{
    self.tintColor = nil;
    self.maskImage = nil;
#if !__has_feature(objc_arc)
	[super dealloc];
#endif
}

+ (MMBlurComponents *) lightEffect {
    MMBlurComponents *components = MB_AUTORELEASE([[MMBlurComponents alloc] init]);
    components.radius = 6;
    components.tintColor = [UIColor colorWithWhite:.8f alpha:.2f];
    components.saturationDeltaFactor = 1.8f;
    components.maskImage = nil;
    return components;
}

+ (MMBlurComponents *) darkEffect {
    MMBlurComponents *components = MB_AUTORELEASE([[MMBlurComponents alloc] init]);
    components.radius = 8;
    components.tintColor = [UIColor colorWithRed:0.0f green:0.0 blue:0.0f alpha:.5f];
    components.saturationDeltaFactor = 3.0f;
    components.maskImage = nil;
    return components;
}

+ (MMBlurComponents *) coralEffect {
    MMBlurComponents *components = MB_AUTORELEASE([[MMBlurComponents alloc] init]);
    components.radius = 8;
    components.tintColor = [UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:.1f];
    components.saturationDeltaFactor = 3.0f;
    components.maskImage = nil;
    return components;
}

+ (MMBlurComponents *) neonEffect {
    MMBlurComponents *components = MB_AUTORELEASE([[MMBlurComponents alloc] init]);
    components.radius = 8;
    components.tintColor = [UIColor colorWithRed:0.0f green:1.0f blue:0.0f alpha:.1f];
    components.saturationDeltaFactor = 3.0f;
    components.maskImage = nil;
    return components;
}

+ (MMBlurComponents *) skyEffect {
    MMBlurComponents *components = MB_AUTORELEASE([[MMBlurComponents alloc] init]);
    components.radius = 8;
    components.tintColor = [UIColor colorWithRed:0.0f green:0.0f blue:1.0f alpha:.1f];
    components.saturationDeltaFactor = 3.0f;
    components.maskImage = nil;
    return components;
}

@end

#import <Accelerate/Accelerate.h>

#define scaleDownFactor 4

@implementation UIImage (ImageEffects)

- (UIImage *)applyBlurWithCrop:(CGRect) bounds resize:(CGSize) size blurRadius:(CGFloat) blurRadius tintColor:(UIColor *) tintColor saturationDeltaFactor:(CGFloat) saturationDeltaFactor maskImage:(UIImage *) maskImage {
    
    if (self.size.width < 1 || self.size.height < 1) {
        NSLog (@"*** error: invalid size: (%.2f x %.2f). Both dimensions must be >= 1: %@", self.size.width, self.size.height, self);
        return nil;
    }
    
    if (!self.CGImage) {
        NSLog (@"*** error: image must be backed by a CGImage: %@", self);
        return nil;
    }
    
    if (maskImage && !maskImage.CGImage) {
        NSLog (@"*** error: maskImage must be backed by a CGImage: %@", maskImage);
        return nil;
    }
    
    //Crop
    UIImage *outputImage = nil;
    
    CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], bounds);
    outputImage = [UIImage imageWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    
    //Re-Size
    CGImageRef sourceRef = [outputImage CGImage];
    NSUInteger sourceWidth = CGImageGetWidth(sourceRef);
    NSUInteger sourceHeight = CGImageGetHeight(sourceRef);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    unsigned char *sourceData = (unsigned char*) calloc(sourceHeight * sourceWidth * 4, sizeof(unsigned char));
    
    NSUInteger bytesPerPixel = 4;
    NSUInteger sourceBytesPerRow = bytesPerPixel * sourceWidth;
    NSUInteger bitsPerComponent = 8;
    
    CGContextRef context = CGBitmapContextCreate(sourceData, sourceWidth, sourceHeight, bitsPerComponent, sourceBytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
    
    CGContextDrawImage(context, CGRectMake(0, 0, sourceWidth, sourceHeight), sourceRef);
    CGContextRelease(context);
    
    NSUInteger destWidth = (NSUInteger) size.width / scaleDownFactor;
    NSUInteger destHeight = (NSUInteger) size.height / scaleDownFactor;
    NSUInteger destBytesPerRow = bytesPerPixel * destWidth;
    
    unsigned char *destData = (unsigned char*) calloc(destHeight * destWidth * 4, sizeof(unsigned char));
    
    vImage_Buffer src = {
        .data = sourceData,
        .height = sourceHeight,
        .width = sourceWidth,
        .rowBytes = sourceBytesPerRow
    };
    
    vImage_Buffer dest = {
        .data = destData,
        .height = destHeight,
        .width = destWidth,
        .rowBytes = destBytesPerRow
    };
    
    vImageScale_ARGB8888 (&src, &dest, NULL, kvImageNoInterpolation);
    
    free(sourceData);
    
    CGContextRef destContext = CGBitmapContextCreate(destData, destWidth, destHeight, bitsPerComponent, destBytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big);
    
    CGImageRef destRef = CGBitmapContextCreateImage(destContext);
    
    outputImage = [UIImage imageWithCGImage:destRef];
    
    CGImageRelease(destRef);
    
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(destContext);
    
    free(destData);
    
    //Blur
    CGRect imageRect = { CGPointZero, outputImage.size };
    
    BOOL hasBlur = blurRadius > __FLT_EPSILON__;
    BOOL hasSaturationChange = fabs(saturationDeltaFactor - 1.) > __FLT_EPSILON__;
    
    if (hasBlur || hasSaturationChange) {
        
        UIGraphicsBeginImageContextWithOptions(outputImage.size, NO, 1);
        
        CGContextRef effectInContext = UIGraphicsGetCurrentContext();
        
        CGContextScaleCTM(effectInContext, 1.0, -1.0);
        CGContextTranslateCTM(effectInContext, 0, -outputImage.size.height);
        CGContextDrawImage(effectInContext, imageRect, outputImage.CGImage);
        
        vImage_Buffer effectInBuffer;
        
        effectInBuffer.data     = CGBitmapContextGetData(effectInContext);
        effectInBuffer.width    = CGBitmapContextGetWidth(effectInContext);
        effectInBuffer.height   = CGBitmapContextGetHeight(effectInContext);
        effectInBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectInContext);
        
        UIGraphicsBeginImageContextWithOptions(outputImage.size, NO, 1);
        
        CGContextRef effectOutContext = UIGraphicsGetCurrentContext();
        vImage_Buffer effectOutBuffer;
        
        effectOutBuffer.data     = CGBitmapContextGetData(effectOutContext);
        effectOutBuffer.width    = CGBitmapContextGetWidth(effectOutContext);
        effectOutBuffer.height   = CGBitmapContextGetHeight(effectOutContext);
        effectOutBuffer.rowBytes = CGBitmapContextGetBytesPerRow(effectOutContext);
        
        if (hasBlur) {
            CGFloat inputRadius = blurRadius * 1;
            NSUInteger radius = floor(inputRadius * 3. * sqrt(2 * M_PI) / 4 + 0.5);
            
            if (radius % 2 != 1) {
                radius += 1;
            }
            
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
            vImageBoxConvolve_ARGB8888(&effectOutBuffer, &effectInBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
            vImageBoxConvolve_ARGB8888(&effectInBuffer, &effectOutBuffer, NULL, 0, 0, radius, radius, 0, kvImageEdgeExtend);
        }
        
        BOOL effectImageBuffersAreSwapped = NO;
        
        if (hasSaturationChange) {
            
            CGFloat s = saturationDeltaFactor;
            CGFloat floatingPointSaturationMatrix[] = {
                0.0722 + 0.9278 * s,  0.0722 - 0.0722 * s,  0.0722 - 0.0722 * s,  0,
                0.7152 - 0.7152 * s,  0.7152 + 0.2848 * s,  0.7152 - 0.7152 * s,  0,
                0.2126 - 0.2126 * s,  0.2126 - 0.2126 * s,  0.2126 + 0.7873 * s,  0,
                0,                    0,                    0,  1,
            };
            
            const int32_t divisor = 256;
            NSUInteger matrixSize = sizeof(floatingPointSaturationMatrix)/sizeof(floatingPointSaturationMatrix[0]);
            int16_t saturationMatrix[matrixSize];
            
            for (NSUInteger i = 0; i < matrixSize; ++i) {
                saturationMatrix[i] = (int16_t)roundf(floatingPointSaturationMatrix[i] * divisor);
            }
            
            if (hasBlur) {
                vImageMatrixMultiply_ARGB8888(&effectOutBuffer, &effectInBuffer, saturationMatrix, divisor, NULL, NULL, kvImageNoFlags);
                effectImageBuffersAreSwapped = YES;
            } else {
                vImageMatrixMultiply_ARGB8888(&effectInBuffer, &effectOutBuffer, saturationMatrix, divisor, NULL, NULL, kvImageNoFlags);
            }
        }
        
        if (!effectImageBuffersAreSwapped)
            outputImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if (effectImageBuffersAreSwapped)
            outputImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    UIGraphicsBeginImageContextWithOptions(outputImage.size, NO, 1);
    CGContextRef outputContext = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(outputContext, 1.0, -1.0);
    CGContextTranslateCTM(outputContext, 0, -outputImage.size.height);
    
    CGContextDrawImage(outputContext, imageRect, outputImage.CGImage);
    
    if (hasBlur) {
        CGContextSaveGState(outputContext);
        if (maskImage) {
            CGContextClipToMask(outputContext, imageRect, maskImage.CGImage);
        }
        CGContextDrawImage(outputContext, imageRect, outputImage.CGImage);
        CGContextRestoreGState(outputContext);
    }
    
    if (tintColor) {
        CGContextSaveGState(outputContext);
        CGContextSetFillColorWithColor(outputContext, tintColor.CGColor);
        CGContextFillRect(outputContext, imageRect);
        CGContextRestoreGState(outputContext);
    }
    
    outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return outputImage;
}

@end

