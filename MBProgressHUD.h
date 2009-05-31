//
//  MBProgressHUD.h
//  Version 0.1
//  Created by Matej Bukovinski on 8.4.09.
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
 * Displays a simple HUD window containing a UIActivityIndicatorView and two optional labels for short messages.
 *
 * This is a simple drop-in class for displaying a progress HUD view similar to Apples private UIProgressHUD class. 
 * The MBProgressHUD window spans over the entire space given to it by the initWithFrame constructor and catches all user 
 * input on this region, thereby preventing the user operations on components below the view. 
 * The HUD itself is drawn centered as a rounded semi-transparent view witch resizes depending on the user specified content. 
 * This view supports three modes of operation:
 * - The default mode displays just a UIActivityIndicatorView. 
 * - If the labelText property is set and non-empty then a label containing the provided content is placed below the UIActivityIndicatorView. 
 * - If also the detailsLabelText property is set then another label is placed below the firs label. 
 */
@interface MBProgressHUD : UIView {

	SEL methodForExecution;
	id targetForExecution;
	id objectForExecution;
	bool useAnimation;
	
	float width;
	float height;
	
	UIActivityIndicatorView *indicator;
	UILabel *label;
	UILabel *detailsLabel;
	
	id delegate;
	NSString *labelText;
	NSString *detailsLabelText;
	float opacity;
	UIFont *labelFont;
	UIFont *detailsLabelFont;
}

/**
 * A convenience constructor tat initializes the HUD with the window's bounds.
 * Calls the designated constructor with window.bounds as the parameter. 
 */
- (id)initWithWindow:(UIWindow *)window;

/** 
 * The HUD delegate object. If set the delegate will receive hudWasHidden callbacks when the hud was hidden.  
 * The delegate should conform to the MBProgressHUDDelegate protocol and implement the hudWasHidden method. 
 */
@property (assign) id delegate;

/**
 * An optional short message to be displayed below the activity indicator. 
 * The HUD is automatically resized to fit the entire text. If the text is too long it will get clipped by displaying "..." at the end.
 * If left unchanged or set to @"", then no message is displayed. 
 */
@property (copy) NSString *labelText;

/**
 * An optional details message displayed below the labelText message.
 * This message is displayed only if the labelText property is also set and is different from an empty string (@"").
 */
@property (copy) NSString *detailsLabelText;

/**
 * The opacity of the hud window. 
 * Defaults to 0.9 (90% opacity).
 */
@property (assign) float opacity;

/**
 * Font to be used for the main label.
 * Set this property if the default is not adequate. 
 */
@property (assign) UIFont *labelFont;

/**
 * Font to be used for the details label.
 * Set this property if the default is not adequate. 
 */
@property (assign) UIFont *detailsLabelFont;

/**
 * Shows the HUD while a background task is executing in a new thread, then hides the HUD.
 * 
 * This method also takes care of NSAutoreleasePools so your method does not have to be concerned with setting up a pool.
 *
 * @param method The method to be executed while the HUD is shown. This method will be executed in a new thread. 
 * @param target The object that the target method belongs to. 
 * @param object An optional object to be passed to the method.
 * @param animated If set to YES the HUD will appear and disappear using a fade animation. 
 *        If set to NO the HUD will not use animations while appearing and disappearing. 
 */
- (void)showWhileExecuting:(SEL)method onTarget:(id)target withObject:(id)object animated:(bool)animated;

/**
 * Display the HUD
 */
- (void) show:(BOOL)animated;

/**
 * Hide the HUD, this still calls the hudWasHidden delegate.
 */
- (void) hide:(BOOL)animated;

@end


/**
 * Defines callback methods for MBProgressHUD delegates.
 */
@protocol MBProgressHUDDelegate 

/**
 * A callback function that is called after the hud was fully hidden from the screen.
 */
- (void)hudWasHidden;

@end

