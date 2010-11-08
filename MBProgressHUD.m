//
// MBProgressHUD.m
// Version 0.4
// Created by Matej Bukovinski on 2.4.09.
//

#import "MBProgressHUD.h"

@interface MBProgressHUD ()

- (void)hideUsingAnimation:(BOOL)animated;
- (void)showUsingAnimation:(BOOL)animated;
- (void)fillRoundedRect:(CGRect)rect inContext:(CGContextRef)context;
- (void)done;
- (void)updateLabelText:(NSString *)newText;
- (void)updateDetailsLabelText:(NSString *)newText;
- (void)updateProgress;
- (void)updateIndicators;
- (void)handleGraceTimer:(NSTimer *)theTimer;
- (void)handleMinShowTimer:(NSTimer *)theTimer;
- (void)setTransformForCurrentOrientation:(BOOL)animated;

@property (retain) UIView *indicator;
@property (assign) float width;
@property (assign) float height;
@property (retain) NSTimer *graceTimer;
@property (retain) NSTimer *minShowTimer;
@property (retain) NSDate *showStarted;

@end


@implementation MBProgressHUD

#pragma mark -
#pragma mark Accessors

@synthesize animationType;

@synthesize delegate;
@synthesize opacity;
@synthesize labelFont;
@synthesize detailsLabelFont;

@synthesize indicator;

@synthesize width;
@synthesize height;
@synthesize xOffset;
@synthesize yOffset;
@synthesize margin;

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
	
	if ([NSThread isMainThread]) {
		[self updateIndicators];
		[self setNeedsLayout];
		[self setNeedsDisplay];
	} else {
		[self performSelectorOnMainThread:@selector(updateIndicators) withObject:nil waitUntilDone:NO];
		[self performSelectorOnMainThread:@selector(setNeedsLayout) withObject:nil waitUntilDone:NO];
		[self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
	}
}

- (MBProgressHUDMode)mode {
	return mode;
}

- (void)setLabelText:(NSString *)newText {
	if ([NSThread isMainThread]) {
		[self updateLabelText:newText];
		[self setNeedsLayout];
		[self setNeedsDisplay];
	} else {
		[self performSelectorOnMainThread:@selector(updateLabelText:) withObject:newText waitUntilDone:NO];
		[self performSelectorOnMainThread:@selector(setNeedsLayout) withObject:nil waitUntilDone:NO];
		[self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
	}
}

- (NSString *)labelText {
	return labelText;
}

- (void)setDetailsLabelText:(NSString *)newText {
	if ([NSThread isMainThread]) {
		[self updateDetailsLabelText:newText];
		[self setNeedsLayout];
		[self setNeedsDisplay];
	} else {
		[self performSelectorOnMainThread:@selector(updateDetailsLabelText:) withObject:newText waitUntilDone:NO];
		[self performSelectorOnMainThread:@selector(setNeedsLayout) withObject:nil waitUntilDone:NO];
		[self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
	}
}

- (NSString *)detailsLabelText {
	return detailsLabelText;
}

- (void)setProgress:(float)newProgress {
    progress = newProgress;
	
    // Update display ony if showing the determinate progress view
    if (mode == MBProgressHUDModeDeterminate) {
		if ([NSThread isMainThread]) {
			[self updateProgress];
			[self setNeedsDisplay];
		} else {
			[self performSelectorOnMainThread:@selector(updateProgress) withObject:nil waitUntilDone:NO];
			[self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
		}
    }
}

- (float)progress {
	return progress;
}

#pragma mark -
#pragma mark Accessor helpers

- (void)updateLabelText:(NSString *)newText {
    if (labelText != newText) {
        [labelText release];
        labelText = [newText copy];
    }
}

- (void)updateDetailsLabelText:(NSString *)newText {
    if (detailsLabelText != newText) {
        [detailsLabelText release];
        detailsLabelText = [newText copy];
    }
}

- (void)updateProgress {
    [(MBRoundProgressView *)indicator setProgress:progress];
}

- (void)updateIndicators {
    if (indicator) {
        [indicator removeFromSuperview];
    }
	
    if (mode == MBProgressHUDModeDeterminate) {
        self.indicator = [[[MBRoundProgressView alloc] initWithDefaultSize] autorelease];
    }
    else if (mode == MBProgressHUDModeCustomView && self.customView != nil){
        self.indicator = self.customView;
    } else {
		self.indicator = [[[UIActivityIndicatorView alloc]
						   initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge] autorelease];
        [(UIActivityIndicatorView *)indicator startAnimating];
	}
	
	
    [self addSubview:indicator];
}

#pragma mark -
#pragma mark Constants

#define PADDING 4.0

#define LABELFONTSIZE 16.0
#define LABELDETAILSFONTSIZE 12.0

#define PI 3.14159265358979323846


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
        // Set default values for properties
        self.animationType = MBProgressHUDAnimationFade;
        self.mode = MBProgressHUDModeIndeterminate;
        self.labelText = nil;
        self.detailsLabelText = nil;
        self.opacity = 0.8;
        self.labelFont = [UIFont boldSystemFontOfSize:LABELFONTSIZE];
        self.detailsLabelFont = [UIFont boldSystemFontOfSize:LABELDETAILSFONTSIZE];
        self.xOffset = 0.0;
        self.yOffset = 0.0;
		self.margin = 20.0;
		self.graceTime = 0.0;
		self.minShowTime = 0.0;
		self.removeFromSuperViewOnHide = NO;
		
		self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		
        // Transparent background
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
		
        // Make invisible for now
        self.alpha = 0.0;
		
        // Add label
        label = [[UILabel alloc] initWithFrame:self.bounds];
		
        // Add details label
        detailsLabel = [[UILabel alloc] initWithFrame:self.bounds];
		
		taskInProgress = NO;
		rotationTransform = CGAffineTransformIdentity;
    }
    return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
    [indicator release];
    [label release];
    [detailsLabel release];
    [labelText release];
    [detailsLabelText release];
	[graceTimer release];
	[minShowTimer release];
	[showStarted release];
	[customView release];
    [super dealloc];
}

#pragma mark -
#pragma mark Layout

- (void)layoutSubviews {
    CGRect frame = self.bounds;
	
    // Compute HUD dimensions based on indicator size (add margin to HUD border)
    CGRect indFrame = indicator.bounds;
    self.width = indFrame.size.width + 2 * margin;
    self.height = indFrame.size.height + 2 * margin;
	
    // Position the indicator
    indFrame.origin.x = floor((frame.size.width - indFrame.size.width) / 2) + self.xOffset;
    indFrame.origin.y = floor((frame.size.height - indFrame.size.height) / 2) + self.yOffset;
    indicator.frame = indFrame;
	
    // Add label if label text was set
    if (nil != self.labelText) {
        // Get size of label text
        CGSize dims = [self.labelText sizeWithFont:self.labelFont];
		
        // Compute label dimensions based on font metrics if size is larger than max then clip the label width
        float lHeight = dims.height;
        float lWidth;
        if (dims.width <= (frame.size.width - 2 * margin)) {
            lWidth = dims.width;
        }
        else {
            lWidth = frame.size.width - 4 * margin;
        }
		
        // Set label properties
        label.font = self.labelFont;
        label.adjustsFontSizeToFitWidth = NO;
        label.textAlignment = UITextAlignmentCenter;
        label.opaque = NO;
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor whiteColor];
        label.text = self.labelText;
		
        // Update HUD size
        if (self.width < (lWidth + 2 * margin)) {
            self.width = lWidth + 2 * margin;
        }
        self.height = self.height + lHeight + PADDING;
		
        // Move indicator to make room for the label
        indFrame.origin.y -= (floor(lHeight / 2 + PADDING / 2));
        indicator.frame = indFrame;
		
        // Set the label position and dimensions
        CGRect lFrame = CGRectMake(floor((frame.size.width - lWidth) / 2) + xOffset,
                                   floor(indFrame.origin.y + indFrame.size.height + PADDING),
                                   lWidth, lHeight);
        label.frame = lFrame;
		
        [self addSubview:label];
		
        // Add details label delatils text was set
        if (nil != self.detailsLabelText) {
            // Get size of label text
            dims = [self.detailsLabelText sizeWithFont:self.detailsLabelFont];
			
            // Compute label dimensions based on font metrics if size is larger than max then clip the label width
            lHeight = dims.height;
            if (dims.width <= (frame.size.width - 2 * margin)) {
                lWidth = dims.width;
            }
            else {
                lWidth = frame.size.width - 4 * margin;
            }
			
            // Set label properties
            detailsLabel.font = self.detailsLabelFont;
            detailsLabel.adjustsFontSizeToFitWidth = NO;
            detailsLabel.textAlignment = UITextAlignmentCenter;
            detailsLabel.opaque = NO;
            detailsLabel.backgroundColor = [UIColor clearColor];
            detailsLabel.textColor = [UIColor whiteColor];
            detailsLabel.text = self.detailsLabelText;
			
            // Update HUD size
            if (self.width < lWidth) {
                self.width = lWidth + 2 * margin;
            }
            self.height = self.height + lHeight + PADDING;
			
            // Move indicator to make room for the new label
            indFrame.origin.y -= (floor(lHeight / 2 + PADDING / 2));
            indicator.frame = indFrame;
			
            // Move first label to make room for the new label
            lFrame.origin.y -= (floor(lHeight / 2 + PADDING / 2));
            label.frame = lFrame;
			
            // Set label position and dimensions
            CGRect lFrameD = CGRectMake(floor((frame.size.width - lWidth) / 2) + xOffset,
                                        lFrame.origin.y + lFrame.size.height + PADDING, lWidth, lHeight);
            detailsLabel.frame = lFrameD;
			
            [self addSubview:detailsLabel];
        }
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
    self.alpha = 0.0;
    
    if(delegate != nil && [delegate conformsToProtocol:@protocol(MBProgressHUDDelegate)]) {
		if([delegate respondsToSelector:@selector(hudWasHidden)]) {
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
    self.alpha = 0.0;
    if (animated && animationType == MBProgressHUDAnimationZoom) {
        self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(1.5, 1.5));
    }
    
	self.showStarted = [NSDate date];
    // Fade in
    if (animated) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.30];
        self.alpha = 1.0;
        if (animationType == MBProgressHUDAnimationZoom) {
            self.transform = rotationTransform;
        }
        [UIView commitAnimations];
    }
    else {
        self.alpha = 1.0;
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
            self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(0.5, 0.5));
        }
        self.alpha = 0.02;
        [UIView commitAnimations];
    }
    else {
        self.alpha = 0.0;
        [self done];
    }
}

#pragma mark BG Drawing

- (void)drawRect:(CGRect)rect {
    // Center HUD
    CGRect allRect = self.bounds;
    // Draw rounded HUD bacgroud rect
    CGRect boxRect = CGRectMake(((allRect.size.width - self.width) / 2) + self.xOffset,
                                ((allRect.size.height - self.height) / 2) + self.yOffset, self.width, self.height);
    CGContextRef ctxt = UIGraphicsGetCurrentContext();
    [self fillRoundedRect:boxRect inContext:ctxt];
}

- (void)fillRoundedRect:(CGRect)rect inContext:(CGContextRef)context {
    float radius = 10.0f;
	
    CGContextBeginPath(context);
    CGContextSetGrayFillColor(context, 0.0, self.opacity);
    CGContextMoveToPoint(context, CGRectGetMinX(rect) + radius, CGRectGetMinY(rect));
    CGContextAddArc(context, CGRectGetMaxX(rect) - radius, CGRectGetMinY(rect) + radius, radius, 3 * M_PI / 2, 0, 0);
    CGContextAddArc(context, CGRectGetMaxX(rect) - radius, CGRectGetMaxY(rect) - radius, radius, 0, M_PI / 2, 0);
    CGContextAddArc(context, CGRectGetMinX(rect) + radius, CGRectGetMaxY(rect) - radius, radius, M_PI / 2, M_PI, 0);
    CGContextAddArc(context, CGRectGetMinX(rect) + radius, CGRectGetMinY(rect) + radius, radius, M_PI, 3 * M_PI / 2, 0);
    CGContextClosePath(context);
    CGContextFillPath(context);
}

#pragma mark -
#pragma mark Manual oritentation change

#define RADIANS(degrees) ((degrees * M_PI) / 180.0)

- (void)deviceOrientationDidChange:(NSNotification *)notification { 
	if (!self.superview) {
		return;
	}
	if ([self.superview isKindOfClass:[UIWindow class]]) {
		[self setTransformForCurrentOrientation:YES];
	}
	// Stay in sync with the parent view (make sure we cover it fully)
	self.frame = self.superview.bounds;
	[self setNeedsDisplay];
}

- (void)setTransformForCurrentOrientation:(BOOL)animated {
	UIDeviceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
	NSInteger degrees = 0;
	
	if (UIInterfaceOrientationIsLandscape(orientation)) {
		if (orientation == UIInterfaceOrientationLandscapeLeft) { degrees = -90; } 
		else { degrees = 90; }
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


@implementation MBRoundProgressView

- (id)initWithDefaultSize {
    return [super initWithFrame:CGRectMake(0.0f, 0.0f, 37.0f, 37.0f)];
}

- (void)drawRect:(CGRect)rect {
    CGRect allRect = self.bounds;
    CGRect circleRect = CGRectMake(allRect.origin.x + 2, allRect.origin.y + 2, allRect.size.width - 4,
                                   allRect.size.height - 4);
	
    CGContextRef context = UIGraphicsGetCurrentContext();
	
    // Draw background
    CGContextSetRGBStrokeColor(context, 1.0, 1.0, 1.0, 1.0); // white
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 0.1); // translucent white
    CGContextSetLineWidth(context, 2.0);
    CGContextFillEllipseInRect(context, circleRect);
    CGContextStrokeEllipseInRect(context, circleRect);
	
    // Draw progress
    float x = (allRect.size.width / 2);
    float y = (allRect.size.height / 2);
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0); // white
    CGContextMoveToPoint(context, x, y);
    CGContextAddArc(context, x, y, (allRect.size.width - 4) / 2, -(PI / 2), (self.progress * 2 * PI) - PI / 2, 0);
    CGContextClosePath(context);
    CGContextFillPath(context);
}

@end
