//
// MBProgressHUD.m
// Version 0.4
// Created by Matej Bukovinski on 2.4.09.
//

#import "MBProgressHUD.h"

@interface MBProgressHUD ()

- (void)hideUsingAnimation:(BOOL)animated;
- (void)showUsingAnimation:(BOOL)animated;
- (void)done;
- (void)handleGraceTimer:(NSTimer *)theTimer;
- (void)handleMinShowTimer:(NSTimer *)theTimer;
- (void)setTransformForCurrentOrientation:(BOOL)animated;
- (void)cleanUp;
- (void)deviceOrientationDidChange:(NSNotification*)notification;
- (void)launchExecution;
- (void)hideDelayed:(NSNumber *)animated;
- (void)addLabelObservers:(UILabel *)label;
- (void)removeLabelObservers:(UILabel *)label;

@property (retain) UIView *indicator;
@property (retain) NSTimer *graceTimer;
@property (retain) NSTimer *minShowTimer;
@property (retain) NSDate *showStarted;

@end

static NSString *MBProgressHUDLabelContext = @"MBProgressHUDLabelContext";


@implementation MBProgressHUD

#pragma mark -
#pragma mark Accessors

@synthesize animationType;

@synthesize delegate;

@synthesize background;
@synthesize indicator;
@synthesize label;
@synthesize detailsLabel;

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

- (void)setMode:(MBProgressHUDMode)newMode {
    // Dont change mode if it wasn't actually changed to prevent flickering
    if (mode && (mode == newMode)) {
        return;
    }
	
    mode = newMode;
	
	if (indicator) {
        [indicator removeFromSuperview];
    }
	
    if (mode == MBProgressHUDModeDeterminate) {
        self.indicator = [[[MBRoundProgressView alloc] init] autorelease];
    }
    else if (mode == MBProgressHUDModeCustomView && self.customView != nil){
        self.indicator = self.customView;
    } else {
		self.indicator = [[[UIActivityIndicatorView alloc]
						   initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge] autorelease];
        [(UIActivityIndicatorView *)indicator startAnimating];
	}
	CGRect indFrame = self.indicator.frame;
	indFrame.origin.y = margin;
	indFrame.origin.x = floorf(background.frame.size.width / 2.0 - indFrame.size.width / 2.0);
	[indicator setFrame:indFrame];
	indicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
	
    [background addSubview:indicator];
	[self setNeedsLayout];
}

- (MBProgressHUDMode)mode {
	return mode;
}

- (void)setProgress:(float)newProgress {
    progress = newProgress;
	
    // Update display ony if showing the determinate progress view
    if (mode == MBProgressHUDModeDeterminate) {
		NSAssert([NSThread isMainThread], @"Must set progress on main thread");
		[(MBRoundProgressView *)indicator setProgress:progress];
    }
}

- (float)progress {
	return progress;
}

#pragma mark -
#pragma mark Constants

#define PADDING 4.0f

#define LABELFONTSIZE 16.0f
#define LABELDETAILSFONTSIZE 12.0f

#pragma mark -
#pragma mark Class methods

+ (MBProgressHUD *)showHUDAddedTo:(UIView *)view animated:(BOOL)animated {
	MBProgressHUD *hud = [[MBProgressHUD alloc] initWithView:view];
	[view addSubview:hud];
	[hud show:animated];
	return [hud autorelease];
}

+ (BOOL)hideHUDForView:(UIView *)view animated:(BOOL)animated {
	UIView *viewToRemove = nil;
	for (UIView *v in [view subviews]) {
		if ([v isKindOfClass:[MBProgressHUD class]]) {
			viewToRemove = v;
		}
	}
	if (viewToRemove != nil) {
		MBProgressHUD *HUD = (MBProgressHUD *)viewToRemove;
		HUD.removeFromSuperViewOnHide = YES;
		[HUD hide:animated];
		return YES;
	} else {
		return NO;
	}
}


#pragma mark -
#pragma mark Lifecycle methods

- (id)initWithWindow:(UIWindow *)window {
    return [self initWithView:window];
}

- (id)initWithView:(UIView *)view {
	// Let's check if the view is nil (this is a common error when using the windw initializer above)
	if (!view) {
		[NSException raise:@"MBProgressHUDViewIsNillException" 
					format:@"The view used in the MBProgressHUD initializer is nil."];
	}
	id me = [self initWithFrame:view.bounds];
	// We need to take care of rotation ourselfs if we're adding the HUD to a window
	if ([view isKindOfClass:[UIWindow class]]) {
		[self setTransformForCurrentOrientation:NO];
	}
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) 
												 name:UIDeviceOrientationDidChangeNotification object:nil];
	
	return me;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
	if (self) {
		background = [[UIView alloc] initWithFrame:self.bounds];
		background.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8f];
		background.opaque = NO;
		background.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleBottomMargin;
		background.layer.cornerRadius = 10.0f;
		[self addSubview:background];
		
        // Set default values for properties
        self.animationType = MBProgressHUDAnimationFade;
		self.margin = 20.0f;
        self.mode = MBProgressHUDModeIndeterminate;
		self.dimBackground = NO;
		self.graceTime = 0.0f;
		self.minShowTime = 0.0f;
		self.removeFromSuperViewOnHide = NO;
		
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
		
        // Transparent background
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
		
        // Make invisible for now
        self.alpha = 0.0f;
		
        // Add label
        label = [[UILabel alloc] initWithFrame:CGRectInset(self.bounds, margin / 2.0, 0)];
		label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        label.font = [UIFont boldSystemFontOfSize:LABELFONTSIZE];
        label.adjustsFontSizeToFitWidth = NO;
        label.textAlignment = UITextAlignmentCenter;
        label.opaque = NO;
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor whiteColor];
		label.hidden = YES;
		[background addSubview:label];
		
        // Add details label
        detailsLabel = [[UILabel alloc] initWithFrame:CGRectInset(self.bounds, margin / 2.0, 0)];
		detailsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		detailsLabel.font = [UIFont boldSystemFontOfSize:LABELDETAILSFONTSIZE];
		detailsLabel.adjustsFontSizeToFitWidth = NO;
		detailsLabel.textAlignment = UITextAlignmentCenter;
		detailsLabel.opaque = NO;
		detailsLabel.backgroundColor = [UIColor clearColor];
		detailsLabel.textColor = [UIColor whiteColor];
		detailsLabel.hidden = YES;
		[background addSubview:detailsLabel];
		
		[self addLabelObservers:label];
		[self addLabelObservers:detailsLabel];
		
		taskInProgress = NO;
		rotationTransform = CGAffineTransformIdentity;
    }
    return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
	
	[self removeLabelObservers:label];
	[self removeLabelObservers:detailsLabel];
	
	[background release];
    [indicator release];
    [label release];
    [detailsLabel release];
	[graceTimer release];
	[minShowTimer release];
	[showStarted release];
	[customView release];
    [super dealloc];
}

#pragma mark -
#pragma mark Layout

- (void)layoutSubviews {
	CGRect bounds = self.bounds;
	
    // Compute HUD dimensions based on indicator size (add margin to HUD border)
	CGRect indFrame = indicator.frame;
	
	CGFloat width = indFrame.size.width + 2 * margin;
    CGFloat height = indFrame.size.height + 2 * margin;
	
    // Add label if label text was set
	label.hidden = (label.text.length == 0);
	detailsLabel.hidden = label.hidden || (detailsLabel.text.length == 0);
	CGFloat lHeight = 0.0f;
	CGFloat dlHeight = 0.0f;
    if (!label.hidden) {
        CGSize dims = [label.text sizeWithFont:label.font];
		lHeight = dims.height;
		
		// Clamp width to bounds less margins
		width = MAX(width, MIN(dims.width, bounds.size.width - 4 * margin) + 2 * margin);
        height += lHeight + PADDING;
				
        if (!detailsLabel.hidden) {
            dims = [detailsLabel.text sizeWithFont:detailsLabel.font];
			dlHeight = dims.height;
			
			width = MAX(width, MIN(dims.width, bounds.size.width - 4 * margin) + 2 * margin);
            height += dims.height + PADDING;
        }
    }
	
	// Center HUD
    CGRect boxRect = CGRectMake(roundf((bounds.size.width - width) / 2),
                                roundf((bounds.size.height - height) / 2), 
								width, height);
	[background setFrame:boxRect];
	
	// Size and position labels
	CGRect lFrame = label.frame;
	lFrame.origin.y = floorf(margin + indFrame.size.height + PADDING);
	lFrame.size.height = lHeight;
	label.frame = lFrame;
	
	CGRect dlFrame = detailsLabel.frame;
	dlFrame.origin.y = lFrame.origin.y + lFrame.size.height + PADDING;
	dlFrame.size.height = dlHeight;
	detailsLabel.frame = dlFrame;
}

+ (NSArray *)labelKeyPaths {
	return [NSArray arrayWithObjects:@"text", @"font", nil];
}

- (void)addLabelObservers:(UILabel *)l {
	for (NSString *key in [MBProgressHUD labelKeyPaths]) {
		[l addObserver:self forKeyPath:key options:0 context:MBProgressHUDLabelContext];
	}
}

- (void)removeLabelObservers:(UILabel *)l {
	for (NSString *key in [MBProgressHUD labelKeyPaths]) {
		[l removeObserver:self forKeyPath:key];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == MBProgressHUDLabelContext) {
        [self setNeedsLayout];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -
#pragma mark Showing and execution

- (void)show:(BOOL)animated {
	useAnimation = animated;
	
	// If the grace time is set postpone the HUD display
	if (self.graceTime > 0.0) {
		self.graceTimer = [NSTimer scheduledTimerWithTimeInterval:self.graceTime 
														   target:self 
														 selector:@selector(handleGraceTimer:) 
														 userInfo:nil 
														  repeats:NO];
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
			self.minShowTimer = [NSTimer scheduledTimerWithTimeInterval:(self.minShowTime - interv) 
																 target:self 
															   selector:@selector(handleMinShowTimer:) 
															   userInfo:nil 
																repeats:NO];
			return;
		} 
	}
	
	// ... otherwise hide the HUD immediately
    [self hideUsingAnimation:useAnimation];
}

- (void)hide:(BOOL)animated afterDelay:(NSTimeInterval)delay {
	[self performSelector:@selector(hideDelayed:) withObject:[NSNumber numberWithBool:delay] afterDelay:delay];
}

- (void)hideDelayed:(NSNumber *)animated {
	[self hide:[animated boolValue]];
}

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

- (void)showWhileExecuting:(SEL)method onTarget:(id)target withObject:(id)object animated:(BOOL)animated {
	
    methodForExecution = method;
    targetForExecution = [target retain];
    objectForExecution = [object retain];
	
    // Launch execution in new thread
	taskInProgress = YES;
    [NSThread detachNewThreadSelector:@selector(launchExecution) toTarget:self withObject:nil];
	
	// Show HUD view
	[self show:animated];
}

- (void)launchExecution {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
    // Start executing the requested task
    [targetForExecution performSelector:methodForExecution withObject:objectForExecution];
	
    // Task completed, update view in main thread (note: view operations should
    // be done only in the main thread)
    [self performSelectorOnMainThread:@selector(cleanUp) withObject:nil waitUntilDone:NO];
	
    [pool release];
}

- (void)animationFinished:(NSString *)animationID finished:(BOOL)finished context:(void*)context {
    [self done];
}

- (void)done {
    isFinished = YES;
	
    // If delegate was set make the callback
    self.alpha = 0.0f;
    
	if(delegate != nil) {
        if ([delegate respondsToSelector:@selector(hudWasHidden:)]) {
            [delegate performSelector:@selector(hudWasHidden:) withObject:self];
        } else if ([delegate respondsToSelector:@selector(hudWasHidden)]) {
            [delegate performSelector:@selector(hudWasHidden)];
        }
	}
	
	if (removeFromSuperViewOnHide) {
		[self removeFromSuperview];
	}
}

- (void)cleanUp {
	taskInProgress = NO;
	
	self.indicator = nil;
	
    [targetForExecution release];
    [objectForExecution release];
	
    [self hide:useAnimation];
}

#pragma mark -
#pragma mark Fade in and Fade out

- (void)showUsingAnimation:(BOOL)animated {
    self.alpha = 0.0f;
    if (animated && animationType == MBProgressHUDAnimationZoom) {
        self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(1.5f, 1.5f));
    }
    
	self.showStarted = [NSDate date];
    // Fade in
    if (animated) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.30];
        self.alpha = 1.0f;
        if (animationType == MBProgressHUDAnimationZoom) {
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
    if (animated) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.30];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(animationFinished: finished: context:)];
        // 0.02 prevents the hud from passing through touches during the animation the hud will get completely hidden
        // in the done method
        if (animationType == MBProgressHUDAnimationZoom) {
            self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(0.5f, 0.5f));
        }
        self.alpha = 0.02f;
        [UIView commitAnimations];
    }
    else {
        self.alpha = 0.0f;
        [self done];
    }
}

#pragma mark BG Drawing

- (void)drawRect:(CGRect)rect {
	
    CGContextRef context = UIGraphicsGetCurrentContext();

    if (dimBackground) {
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
}

#pragma mark -
#pragma mark Manual oritentation change

#define RADIANS(degrees) ((degrees * (float)M_PI) / 180.0f)

- (void)deviceOrientationDidChange:(NSNotification *)notification { 
	if (!self.superview) {
		return;
	}
	if ([self.superview isKindOfClass:[UIWindow class]]) {
		[self setTransformForCurrentOrientation:YES];
	}
}

- (void)setTransformForCurrentOrientation:(BOOL)animated {
	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	NSInteger degrees = 0;
	
	// Stay in sync with the superview
	if (self.superview) {
		self.bounds = self.superview.bounds;
		[self setNeedsDisplay];
	}
	
	if (UIInterfaceOrientationIsLandscape(orientation)) {
		if (orientation == UIInterfaceOrientationLandscapeLeft) { degrees = -90; } 
		else { degrees = 90; }
		// Window coordinates differ!
		self.bounds = CGRectMake(0, 0, self.bounds.size.height, self.bounds.size.width);
	} else {
		if (orientation == UIInterfaceOrientationPortraitUpsideDown) { degrees = 180; } 
		else { degrees = 0; }
	}
	
	rotationTransform = CGAffineTransformMakeRotation(RADIANS(degrees));

	if (animated) {
		[UIView beginAnimations:nil context:nil];
	}
	[self setTransform:rotationTransform];
	if (animated) {
		[UIView commitAnimations];
	}
}

@end

/////////////////////////////////////////////////////////////////////////////////////////////

@implementation MBRoundProgressView

#pragma mark -
#pragma mark Accessors

- (float)progress {
    return _progress;
}

- (void)setProgress:(float)progress {
    _progress = progress;
    [self setNeedsDisplay];
}

#pragma mark -
#pragma mark Lifecycle

- (id)init {
    return [self initWithFrame:CGRectMake(0.0f, 0.0f, 37.0f, 37.0f)];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
		self.opaque = NO;
    }
    return self;
}

#pragma mark -
#pragma mark Drawing

- (void)drawRect:(CGRect)rect {
    
    CGRect allRect = self.bounds;
    CGRect circleRect = CGRectInset(allRect, 2.0f, 2.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Draw background
    CGContextSetRGBStrokeColor(context, 1.0f, 1.0f, 1.0f, 1.0f); // white
    CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 0.1f); // translucent white
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

@end

/////////////////////////////////////////////////////////////////////////////////////////////
