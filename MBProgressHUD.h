//
//  MBProgressHUD.h
//  Version 0.31
//  Created by Matej Bukovinski on 30.9.09.
//

// This code is distributed under the terms and conditions of the MIT license. 

// Copyright (c) 2009 Matej Bukovinski
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

/**
 * MBProgressHUD operation modes.
 */
typedef enum {
    /** Progress is shown using an UIActivityIndicatorView. This is the default. */
    MBProgressHUDModeIndeterminate,
    /** Progress is shown using a MBRoundProgressView. */
	MBProgressHUDModeDeterminate,
} MBProgressHUDMode;


/**
 * Defines callback methods for MBProgressHUD delegates.
 */
@protocol MBProgressHUDDelegate <NSObject>

@required
/** 
 * A callback function that is called after the HUD was fully hidden from the screen. 
 */
- (void)hudWasHidden;

@end


/**
 * A progress view for showing definite progress by filling up a circle (similar to the indicator for building in xcode).
 */
@interface MBRoundProgressView : UIProgressView {

}

/**
 * Create a 37 by 37 pixel indicator. 
 * This is the same size as used by the larger UIActivityIndicatorView.
 */
- (id)initWithDefaultSize;

@end

/** 
 * Displays a simple HUD window containing a UIActivityIndicatorView and two optional labels for short messages.
 *
 * This is a simple drop-in class for displaying a progress HUD view similar to Apples private UIProgressHUD class.
 * The MBProgressHUD window spans over the entire space given to it by the initWithFrame constructor and catches all
 * user input on this region, thereby preventing the user operations on components below the view. The HUD itself is
 * drawn centered as a rounded semi-transparent view witch resizes depending on the user specified content.
 *
 * This view supports three modes of operation:
 * - The default mode displays just a UIActivityIndicatorView.
 * - If the labelText property is set and non-empty then a label containing the provided content is placed below the
 *   UIActivityIndicatorView.
 * - If also the detailsLabelText property is set then another label is placed below the first label.
 */
@interface MBProgressHUD : UIView {
	
	MBProgressHUDMode mode;

	SEL methodForExecution;
	id targetForExecution;
	id objectForExecution;
	BOOL useAnimation;

    float yOffset;
    float xOffset;

	float width;
	float height;

    NSUInteger delay;

	UIView *indicator;
	UILabel *label;
	UILabel *detailsLabel;

	float progress;

	id<MBProgressHUDDelegate> delegate;
	NSString *labelText;
	NSString *detailsLabelText;
	float opacity;
	UIFont *labelFont;
	UIFont *detailsLabelFont;

    BOOL isFinished;
}

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
 * MBProgressHUD operation mode. Switches between indeterminate (MBProgressHUDModeIndeterminate) and determinate
 * progress (MBProgressHUDModeDeterminate). The default is MBProgressHUDModeIndeterminate.
 */
@property (assign) MBProgressHUDMode mode;

/** 
 * The HUD delegate object. If set the delegate will receive hudWasHidden callbacks when the HUD was hidden. The
 * delegate should conform to the MBProgressHUDDelegate protocol and implement the hudWasHidden method. The delegate
 * object will not be retained.
 */
@property (assign) id<MBProgressHUDDelegate> delegate;

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
 * The x-axis offset of the HUD relative to the centre of the window. 
 */
@property (assign) float xOffset;

/** 
 *The y-ayis offset of the HUD relative to the centre of the window. 
 */
@property (assign) float yOffset;

/** 
 *The number of milliseconds to displaying the HUD after start. 
 */
@property (assign) NSUInteger delay;

/** 
 * Font to be used for the main label. Set this property if the default is not adequate. 
 */
@property (retain) UIFont* labelFont;

/** 
 * Font to be used for the details label. Set this property if the default is not adequate. 
 */
@property (retain) UIFont* detailsLabelFont;

/** 
 * The progress of the progress indicator, from 0.0 to 1.0. Defaults to 0.0. 
 */
@property (assign) float progress;

/** 
 * Display the HUD. You need to make sure that the main thread completes its run loop soon after this method call so
 * the user interface can be updated. Call this method when your task is already set-up to be executed in a new thread
 * (e.g., when using something like NSOperation or calling an asynchronous call like NSUrlRequest).
 *
 * @param animated If set to YES the HUD will appear using a fade animation. If set to NO the HUD will not use
 * animations while appearing.
 */
- (void)show:(BOOL)animated;

/** 
 * Hide the HUD, this still calls the hudWasHidden delegate. This is the counterpart of the hide: method. Use it to
 * hide the HUD when your task completes.
 *
 * @param animated If set to YES the HUD will disappear using a fade animation. If set to NO the HUD will not use
 * animations while disappearing.
 */
- (void)hide:(BOOL)animated;

/** 
 * Shows the HUD while a background task is executing in a new thread, then hides the HUD.
 *
 * This method also takes care of NSAutoreleasePools so your method does not have to be concerned with setting up a
 * pool.
 *
 * @param method The method to be executed while the HUD is shown. This method will be executed in a new thread.
 * @param target The object that the target method belongs to.
 * @param object An optional object to be passed to the method.
 * @param animated If set to YES the HUD will appear and disappear using a fade animation. If set to NO the HUD will
 * not use animations while appearing and disappearing.
 */
- (void)showWhileExecuting:(SEL)method onTarget:(id)target withObject:(id)object animated:(BOOL)animated;

@end
