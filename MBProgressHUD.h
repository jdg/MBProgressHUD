//
//  MBProgressHUD.h
//  Version 0.4
//  Created by Matej Bukovinski on 2.4.09.
//

// This code is distributed under the terms and conditions of the MIT license. 

// Copyright (c) 2011 Matej Bukovinski
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <UIKit/UIKit.h>

@protocol MBProgressHUDDelegate;

/////////////////////////////////////////////////////////////////////////////////////////////

typedef enum {
    /** Progress is shown using an UIActivityIndicatorView. This is the default. */
    MBProgressHUDModeIndeterminate,
    /** Progress is shown using a MBRoundProgressView. */
	MBProgressHUDModeDeterminate,
	/** Shows a custom view */
	MBProgressHUDModeCustomView
} MBProgressHUDMode;

typedef enum {
    /** Opacity animation */
    MBProgressHUDAnimationFade,
    /** Opacity + scale animation */
    MBProgressHUDAnimationZoom
} MBProgressHUDAnimation;

/////////////////////////////////////////////////////////////////////////////////////////////

/** 
 * Displays a simple HUD window containing a progress indicator and two optional labels for short messages.
 *
 * This is a simple drop-in class for displaying a progress HUD view similar to Apples private UIProgressHUD class.
 * The MBProgressHUD window spans over the entire space given to it by the initWithFrame constructor and catches all
 * user input on this region, thereby preventing the user operations on components below the view. The HUD itself is
 * drawn centered as a rounded semi-transparent view witch resizes depending on the user specified content.
 *
 * This view supports three modes of operation:
 * - MBProgressHUDModeIndeterminate - shows a UIActivityIndicatorView
 * - MBProgressHUDModeDeterminate - shows a custom round progress indicator (MBRoundProgressView)
 * - MBProgressHUDModeCustomView - shows an arbitrary, user specified view (@see customView)
 *
 * All three modes can have optional labels assigned:
 * - If the labelText property is set and non-empty then a label containing the provided content is placed below the
 *   indicator view.
 * - If also the detailsLabelText property is set then another label is placed below the first label.
 */
@interface MBProgressHUD : UIView {
	
	MBProgressHUDMode mode;
    MBProgressHUDAnimation animationType;
	
	SEL methodForExecution;
	id targetForExecution;
	id objectForExecution;
	BOOL useAnimation;
	
    float yOffset;
    float xOffset;
	
	float width;
	float height;
	
	CGSize minSize;
	BOOL square;
	
	float margin;
	
	BOOL dimBackground;
	
	BOOL taskInProgress;
	float graceTime;
	float minShowTime;
	NSTimer *graceTimer;
	NSTimer *minShowTimer;
	NSDate *showStarted;
	
	UIView *indicator;
	UILabel *label;
	UILabel *detailsLabel;
	
	float progress;
	
#if __has_feature(objc_arc)
	id<MBProgressHUDDelegate> __weak delegate;
#else
	id<MBProgressHUDDelegate> delegate;
#endif
    NSString *labelText;
	NSString *detailsLabelText;
	float opacity;
	UIFont *labelFont;
	UIFont *detailsLabelFont;
	
    BOOL isFinished;
	BOOL removeFromSuperViewOnHide;
	
	UIView *customView;
	
	CGAffineTransform rotationTransform;
}

/**
 * Creates a new HUD, adds it to provided view and shows it. The counterpart to this method is hideHUDForView:animated:.
 * 
 * @param view The view that the HUD will be added to
 * @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
 * animations while disappearing.
 * @return A reference to the created HUD.
 *
 * @see hideHUDForView:animated:
 */
+ (MBProgressHUD *)showHUDAddedTo:(UIView *)view animated:(BOOL)animated;

/**
 * Finds a HUD subview and hides it. The counterpart to this method is showHUDAddedTo:animated:.
 *
 * @param view The view that is going to be searched for a HUD subview.
 * @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
 * animations while disappearing.
 * @return YES if a HUD was found and removed, NO otherwise. 
 *
 * @see hideHUDForView:animated:
 */
+ (BOOL)hideHUDForView:(UIView *)view animated:(BOOL)animated;

/** 
 * A convenience constructor that initializes the HUD with the window's bounds. Calls the designated constructor with
 * window.bounds as the parameter.
 *
 * @param window The window instance that will provide the bounds for the HUD. Should probably be the same instance as
 * the HUD's superview (i.e., the window that the HUD will be added to).
 */
- (id)initWithWindow:(UIWindow *)window;

/**
 * A convenience constructor that initializes the HUD with the view's bounds. Calls the designated constructor with
 * view.bounds as the parameter
 * 
 * @param view The view instance that will provide the bounds for the HUD. Should probably be the same instance as
 * the HUD's superview (i.e., the view that the HUD will be added to).
 */
- (id)initWithView:(UIView *)view;

/**
 * The UIView (i.g., a UIIMageView) to be shown when the HUD is in MBProgressHUDModeCustomView.
 * For best results use a 37 by 37 pixel view (so the bounds match the build in indicator bounds). 
 */
#if __has_feature(objc_arc)
@property (strong) UIView *customView;
#else
@property (retain) UIView *customView;
#endif
/** 
 * MBProgressHUD operation mode. Switches between indeterminate (MBProgressHUDModeIndeterminate) and determinate
 * progress (MBProgressHUDModeDeterminate). The default is MBProgressHUDModeIndeterminate.
 *
 * @see MBProgressHUDMode
 */
@property (assign) MBProgressHUDMode mode;

/**
 * The animation type that should be used when the HUD is shown and hidden. 
 *
 * @see MBProgressHUDAnimation
 */
@property (assign) MBProgressHUDAnimation animationType;

/** 
 * The HUD delegate object. If set the delegate will receive hudWasHidden callbacks when the HUD was hidden. The
 * delegate should conform to the MBProgressHUDDelegate protocol and implement the hudWasHidden method. The delegate
 * object will not be retained.
 */
#if __has_feature(objc_arc)
@property (weak) id<MBProgressHUDDelegate> delegate;
#else
@property (assign) id<MBProgressHUDDelegate> delegate;
#endif
/** 
 * An optional short message to be displayed below the activity indicator. The HUD is automatically resized to fit
 * the entire text. If the text is too long it will get clipped by displaying "..." at the end. If left unchanged or
 * set to @"", then no message is displayed.
 */
@property (copy) NSString *labelText;

/** 
 * An optional details message displayed below the labelText message. This message is displayed only if the labelText
 * property is also set and is different from an empty string (@"").
 */
@property (copy) NSString *detailsLabelText;

/** 
 * The opacity of the HUD window. Defaults to 0.9 (90% opacity). 
 */
@property (assign) float opacity;

/** 
 * The x-axis offset of the HUD relative to the centre of the superview. 
 */
@property (assign) float xOffset;

/** 
 * The y-ayis offset of the HUD relative to the centre of the superview. 
 */
@property (assign) float yOffset;

/**
 * The amounth of space between the HUD edge and the HUD elements (labels, indicators or custom views).
 *
 * Defaults to 20.0
 */
@property (assign) float margin;

/** 
 * Cover the HUD background view with a radial gradient. 
 */
@property (assign) BOOL dimBackground;

/*
 * Grace period is the time (in seconds) that the invoked method may be run without 
 * showing the HUD. If the task finishes befor the grace time runs out, the HUD will
 * not be shown at all. 
 * This may be used to prevent HUD display for very short tasks.
 * Defaults to 0 (no grace time).
 * Grace time functionality is only supported when the task status is known!
 * @see taskInProgress
 */
@property (assign) float graceTime;


/**
 * The minimum time (in seconds) that the HUD is shown. 
 * This avoids the problem of the HUD being shown and than instantly hidden.
 * Defaults to 0 (no minimum show time).
 */
@property (assign) float minShowTime;

/**
 * Indicates that the executed operation is in progress. Needed for correct graceTime operation.
 * If you don't set a graceTime (different than 0.0) this does nothing.
 * This property is automatically set when using showWhileExecuting:onTarget:withObject:animated:.
 * When threading is done outside of the HUD (i.e., when the show: and hide: methods are used directly),
 * you need to set this property when your task starts and completes in order to have normal graceTime 
 * functunality.
 */
@property (assign) BOOL taskInProgress;

/**
 * Removes the HUD from it's parent view when hidden. 
 * Defaults to NO. 
 */
@property (assign) BOOL removeFromSuperViewOnHide;

/** 
 * Font to be used for the main label. Set this property if the default is not adequate. 
 */
#if __has_feature(objc_arc)
@property (strong) UIFont* labelFont;
#else
@property (retain) UIFont* labelFont;
#endif
/** 
 * Font to be used for the details label. Set this property if the default is not adequate. 
 */
#if __has_feature(objc_arc)
@property (strong) UIFont* detailsLabelFont;
#else
@property (retain) UIFont* detailsLabelFont;
#endif
/** 
 * The progress of the progress indicator, from 0.0 to 1.0. Defaults to 0.0. 
 */
@property (assign) float progress;

/**
 * The minimum size of the HUD bezel. Defaults to CGSizeZero.
 */
@property (assign) CGSize minSize;

/**
 * Force the HUD dimensions to be equal if possible. 
 */
@property (assign, getter = isSquare) BOOL square;

/** 
 * Display the HUD. You need to make sure that the main thread completes its run loop soon after this method call so
 * the user interface can be updated. Call this method when your task is already set-up to be executed in a new thread
 * (e.g., when using something like NSOperation or calling an asynchronous call like NSUrlRequest).
 *
 * If you need to perform a blocking thask on the main thread, you can try spining the run loop imeidiately after calling this 
 * method by using:
 *
 * [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantPast]];
 *
 * @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
 * animations while disappearing.
 */
- (void)show:(BOOL)animated;

/** 
 * Hide the HUD. This still calls the hudWasHidden delegate. This is the counterpart of the hide: method. Use it to
 * hide the HUD when your task completes.
 *
 * @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
 * animations while disappearing.
 */
- (void)hide:(BOOL)animated;

/** 
 * Hide the HUD after a delay. This still calls the hudWasHidden delegate. This is the counterpart of the hide: method. Use it to
 * hide the HUD when your task completes.
 *
 * @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
 * animations while disappearing.
 * @param delay Delay in secons until the HUD is hidden.
 */
- (void)hide:(BOOL)animated afterDelay:(NSTimeInterval)delay;

/** 
 * Shows the HUD while a background task is executing in a new thread, then hides the HUD.
 *
 * This method also takes care of NSAutoreleasePools so your method does not have to be concerned with setting up a
 * pool.
 *
 * @param method The method to be executed while the HUD is shown. This method will be executed in a new thread.
 * @param target The object that the target method belongs to.
 * @param object An optional object to be passed to the method.
 * @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
 * animations while disappearing.
 */
- (void)showWhileExecuting:(SEL)method onTarget:(id)target withObject:(id)object animated:(BOOL)animated;

@end

/////////////////////////////////////////////////////////////////////////////////////////////

@protocol MBProgressHUDDelegate <NSObject>

@optional

/** 
 * Called after the HUD was fully hidden from the screen. 
 */
- (void)hudWasHidden:(MBProgressHUD *)hud;

/**
 * @deprecated use hudWasHidden: instead
 * @see hudWasHidden:
 */
- (void)hudWasHidden __attribute__ ((deprecated)); 

@end

/////////////////////////////////////////////////////////////////////////////////////////////

/**
 * A progress view for showing definite progress by filling up a circle (pie chart).
 */
@interface MBRoundProgressView : UIView {
@private
    float _progress;
}

/**
 * Progress (0.0 to 1.0)
 */
@property (nonatomic, assign) float progress;

@end

/////////////////////////////////////////////////////////////////////////////////////////////

