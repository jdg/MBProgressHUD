//
//  MBProgressHUD.swift
//  Version 1.0
//  Created by Matej Bukovinski on 2.4.09.
//  Ported to swift by Stephen Orr on 6.15.17
//

// This code is distributed under the terms and conditions of the MIT license.

// Copyright © 2009-2016 Matej Bukovinski
// Swift implementation copyright Stephen Orr
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

import UIKit

protocol MBProgressHUDDelegate: class {
    func hudWasHidden(hud: MBProgressHUD) -> Void
}

/**
 * Displays a simple HUD window containing a progress indicator and two optional labels for short messages.
 *
 * This is a simple drop-in class for displaying a progress HUD view similar to Apple's private UIProgressHUD class.
 * The MBProgressHUD window spans over the entire space given to it by the initWithFrame: constructor and catches all
 * user input on this region, thereby preventing the user operations on components below the view.
 *
 * @note To still allow touches to pass through the HUD, you can set hud.userInteractionEnabled = NO.
 * @attention MBProgressHUD is a UI class and should therefore only be accessed on the main thread.
 * @note Swift implementation drops support for pre-ios7 and deprecated features from the MBProgressHUD v1.0
 */
class MBProgressHUD: UIView {
    
    typealias MBProgressHUDCompletionBlock = () -> ()

    enum MBProgressHUDMode                  {
        /// UIActivityIndicatorView.
        case MBProgressHUDModeIndeterminate
        /// A round, pie-chart like, progress view.
        case MBProgressHUDModeDeterminate
        /// Horizontal progress bar.
        case MBProgressHUDModeDeterminateHorizontalBar
        /// Ring-shaped progress view.
        case MBProgressHUDModeAnnularDeterminate
        /// Shows a custom view.
        case MBProgressHUDModeCustomView
        /// Shows only labels.
        case MBProgressHUDModeText
    }
    enum MBProgressHUDAnimation             {
        /// Opacity animation
        case MBProgressHUDAnimationFade
        /// Opacity + scale animation
        case MBProgressHUDAnimationZoom
        /// Opacity + scale animation (zoom out style)
        case MBProgressHUDAnimationZoomOut
        /// Opacity + scale animation (zoom in style)
        case MBProgressHUDAnimationZoomIn
    }
    
    static let shared = MBProgressHUD.hiddenHUDAddedTo(UIApplication.shared.keyWindow!)
 
    var animationType:MBProgressHUDAnimation = .MBProgressHUDAnimationFade
    /**
     * Removes the HUD from its parent view when hidden.
     * Defaults to NO.
     */
    var removeFromSuperViewOnHide   = false
    /*
     * graceTime is the time (in seconds) that the invoked method may be run without
     * showing the HUD. If the task finishes before the grace time runs out, the HUD will
     * not be shown at all.
     * This may be used to prevent HUD display for very short tasks.
     * Defaults to 0 (no grace time).
     */
    var graceTime:TimeInterval      = 0.0
    /**
     * The minimum time (in seconds) that the HUD is shown.
     * This avoids the problem of the HUD being shown and than instantly hidden.
     * Defaults to 0 (no minimum show time).
     */
    var minShowTime:TimeInterval    = 0.0
    /**
     * A button that is placed below the labels. Visible only if a target / action is added.
     */
    var button:UIButton             = MBProgressHUDRoundedButton(type: .custom)
    weak var delegate               : MBProgressHUDDelegate?
    var completion                  : MBProgressHUDCompletionBlock?
    var label                       = UILabel()
    var detailsLabel                = UILabel()
    var opacity:CGFloat             = 1.0
    var margin: CGFloat = 20.0 {
        didSet {
            dispatchOnMainThread {
                self.setNeedsUpdateConstraints()
            }
        }
    }
    var borderWidth = CGFloat(0) {
        didSet {
            bezelView.layer.borderWidth = borderWidth
        }
    }
    var borderColor = UIColor.black {
        didSet {
            bezelView.layer.borderColor = borderColor.cgColor
        }
    }
    var square = false {
        didSet {
            dispatchOnMainThread {
                self.setNeedsUpdateConstraints()
            }
        }
    }
    var customView: UIView? {
        didSet {
            //
            // Add constraints to width and height to ensure the
            // customview doesn't collapse when we add it to our layout
            if let view = customView {
                let width = view.frame.size.width
                let height = view.frame.size.height
                view.addConstraint(NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal, toItem: nil,
                                                 attribute: .notAnAttribute, multiplier: 1, constant: height))
                view.addConstraint(NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: width))
            }
            if mode == .MBProgressHUDModeCustomView {
                dispatchOnMainThread {
                    self.updateIndicators()
                    self.setNeedsLayout()
                    self.setNeedsDisplay()
                }
            }
        }
    }
    var labelAboveIndicator = false {
        didSet {
            dispatchOnMainThread {
                self.updateIndicators()
                self.setNeedsLayout()
                self.setNeedsDisplay()
            }
        }
    }
    var contentColor = UIColor(white: 0.0, alpha: 0.7)  {
        didSet {
            updateViews(forColor: contentColor)
        }
    }
    var activityIndicatorColor: UIColor? {
        didSet {
            updateViews(forColor: contentColor)
        }
    }
    var mode:MBProgressHUDMode {
        didSet {
            dispatchOnMainThread {
                self.updateIndicators()
            }
        }
    }
    var progress:CGFloat {
        didSet {
            if (mode == .MBProgressHUDModeDeterminate) {
                dispatchOnMainThread {
                    let selector = NSSelectorFromString("setProgress:")
                    if (self.indicator?.responds(to: selector))! {
                        self.indicator!.perform(selector, with: self.progress)
                    }
                }
            }
        }
    }
    var offset = CGPoint.zero {
        didSet {
            dispatchOnMainThread {
                self.setNeedsUpdateConstraints()
            }
        }
    }
    var progressObjectDisplayLink:CADisplayLink? {
        willSet {
            if (progressObjectDisplayLink != newValue) {
                progressObjectDisplayLink?.invalidate()
                if (newValue != nil) {
                    newValue!.add(to: RunLoop.main, forMode: .defaultRunLoopMode)
                }
            }
        }
    }
    /**
     * The NSProgress object feeding the progress information to the progress indicator.
     */
    var progressObject:Progress? {
        didSet {
            setProgressDisplayLink(enabled: true)
        }
    }
    var defaultMotionEffectsEnabled = true {
        didSet {
            dispatchOnMainThread {
                self.updateBezelMotionEffects()
            }
        }
    }
    var minSize = CGSize.zero {
        didSet {
            dispatchOnMainThread {
                self.setNeedsUpdateConstraints()
            }
        }
    }

    private var width: CGFloat      = 0.0
    private var height: CGFloat     = 0.0
    private var indicator           : UIView?
    private var topSpacer           = UIView()
    private var bottomSpacer        = UIView()
    private var graceTimer          : Timer?
    private var minShowTimer        : Timer?
    private var hideDelayedTimer    : Timer?
    private var showStarted         : Date?
    private var isFinished          = false
    private var rotationTransform   : CGAffineTransform?
    private var bezelView           = MBBackgroundView()
    private var backgroundView      = MBBackgroundView()
    private var bezelConstraints    = Array<NSLayoutConstraint>()
    private var paddingConstraints  = Array<NSLayoutConstraint>()
    private var useAnimation        = false
    
    // MARK -- Constants
    private let MBPadding:CGFloat               = 4.0
    private let MBLabelFontSize:CGFloat         = 16.0
    private let MBDetailLabelFontSize:CGFloat   = 12.0
    
    // MARK -- Static Class methods
    static func showHUDAddedTo(_ view:UIView, animated: Bool = true) -> MBProgressHUD               {
        /**
         * Creates a new HUD, adds it to provided view and shows it. The counterpart to this method is hideHUDForView:animated:.
         *
         * @note This method sets removeFromSuperViewOnHide. The HUD will automatically be removed from the view hierarchy when hidden.
         *
         * @param view The view that the HUD will be added to
         * @param animated If set to YES the HUD will appear using the current animationType. If set to NO the HUD will not use
         * animations while appearing.
         * @return A reference to the created HUD.
         *
         * @see hideHUDForView:animated:
         * @see animationType
         */
        let hud = MBProgressHUD(view: view)
        hud.removeFromSuperViewOnHide = true
        view.addSubview(hud)
        hud.show(animated: animated)
        return hud
    }
    static func hiddenHUDAddedTo(_ view:UIView) -> MBProgressHUD                                    {
        /**
         * Creates a new HUD, adds it to provided view and does NOT show it. The counterpart to this method is hideHUDForView:animated:.
         *
         * @note This method sets removeFromSuperViewOnHide. The HUD will automatically be removed from the view hierarchy when hidden.
         *
         * @param view The view that the HUD will be added to
         * @param animated If set to YES the HUD will appear using the current animationType. If set to NO the HUD will not use
         * animations while appearing.
         * @return A reference to the created HUD.
         *
         * @see hideHUDForView:animated:
         * @see animationType
         */
        let hud = MBProgressHUD(view: view)
        hud.removeFromSuperViewOnHide = true
        view.addSubview(hud)
        return hud
    }

    static func hideHUDFor(_ view: UIView, animated: Bool = true) -> Bool                           {
        /**
         * Finds the top-most HUD subview and hides it. The counterpart to this method is showHUDAddedTo:animated:.
         *
         * @note This method sets removeFromSuperViewOnHide. The HUD will automatically be removed from the view hierarchy when hidden.
         *
         * @param view The view that is going to be searched for a HUD subview.
         * @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
         * animations while disappearing.
         * @return YES if a HUD was found and removed, NO otherwise.
         *
         * @see showHUDAddedTo:animated:
         * @see animationType
         */
        let hud = HUDFor(view)
        if hud != nil {
            hud?.removeFromSuperViewOnHide = true
            hud!.hide(animated: animated)
            return true
        }
        return false
    }
    static func HUDFor(_ view:UIView) -> MBProgressHUD?                                             {
        /**
         * Finds the top-most HUD subview and returns it.
         *
         * @param view The view that is going to be searched.
         * @return A reference to the last HUD subview discovered.
         */
        for subView in view.subviews.reversed() {
            if let hud = subView as? MBProgressHUD {
                return hud
            }
        }
        return nil
    }

    // MARK -- Lifecycle methods
    required init?(coder aDecoder: NSCoder)                                                         {
        // Set default values for properties
        mode                = .MBProgressHUDModeIndeterminate
        progress            = 0
        
        super.init(coder: aDecoder)
        
        // Set some other properties now that 'super' has run.
        commonInit()
    }
    override init(frame: CGRect)                                                                    {
        // Set default values for properties
        mode                = .MBProgressHUDModeIndeterminate
        progress            = 0

        super.init(frame:frame)
        
        // Set some other properties now that 'super' has run.
        commonInit()
    }
    override func removeFromSuperview()                                                             {
        NotificationCenter.default.removeObserver(self)
        super.removeFromSuperview()
    }
    convenience init(view: UIView)                                                                  {
        /**
         * A convenience constructor that initializes the HUD with the view's bounds. Calls the designated constructor with
         * view.bounds as the parameter.
         *
         * @param withView The view instance that will provide the bounds for the HUD. Should be the same instance as
         * the HUD's superview (i.e., the view that the HUD will be added to).
         */
        self.init(frame: view.bounds)
        // We need to take care of rotation ourselves if we're adding the HUD to a window
    }
    override func didMoveToSuperview()                                                              {
        updateForCurrentOrientation(animated: false)
        super.didMoveToSuperview()
    }
    deinit                                                                                          {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK -- Showing and hiding
    func show(animated: Bool = true)                                                                {
        /**
         * Displays the HUD.
         *
         * @note You need to make sure that the main thread completes its run loop soon after this method call so that
         * the user interface can be updated. Call this method when your task is already set up to be executed in a new thread
         * (e.g., when using something like NSOperation or making an asynchronous call like NSURLRequest).
         *
         * @param animated If set to YES the HUD will appear using the current animationType. If set to NO the HUD will not use
         * animations while appearing.
         *
         * @see animationType
         */
        useAnimation = animated
        minShowTimer?.invalidate()
        isFinished = false
        
        if graceTime > 0.0 {
            // If the grace time is set postpone the HUD display
            self.graceTimer = Timer.scheduledTimer(timeInterval: graceTime,
                                                   target: self,
                                                   selector: #selector(handleGraceTimer(theTimer:)),
                                                   userInfo: nil,
                                                   repeats: false)
        } else {
            // ... otherwise show the HUD imediately
            showUsingAnimation(useAnimation)
        }
    }
    func hide(animated: Bool = true)                                                                {
        /**
         * Hides the HUD. This still calls the hudWasHidden: delegate. This is the counterpart of the show: method. Use it to
         * hide the HUD when your task completes.
         *
         * @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
         * animations while disappearing.
         *
         * @see animationType
         */
        useAnimation = animated
        graceTimer?.invalidate()
        isFinished = true
        
        // If the minShow time is set, calculate how long the hud was shown,
        // and pospone the hiding operation if necessary
        if minShowTime > 0.0, let started = showStarted {
            let interv = Date().timeIntervalSince(started)
            if (interv < minShowTime) {
                minShowTimer = Timer.scheduledTimer(timeInterval: minShowTime-interv,
                                                    target: self,
                                                    selector: #selector(handleMinShowTimer),
                                                    userInfo: nil,
                                                    repeats: false)
                return
            }
        }
        // ... otherwise hide the HUD immediately
        hideUsingAnimation(useAnimation)
    }
    func hide(animated: Bool = true, after: TimeInterval)                                           {
        /**
         * Hides the HUD after a delay. This still calls the hudWasHidden: delegate. This is the counterpart of the show: method. Use it to
         * hide the HUD when your task completes.
         *
         * @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
         * animations while disappearing.
         * @param delay Delay in seconds until the HUD is hidden.
         *
         * @see animationType
         */
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+after, execute: {() in
            self.hide(animated: animated)
        })
    }

    // MARK -- private show & hide operations
    @objc private func handleGraceTimer(theTimer: Timer)                                            {
        // Show the HUD only if the task is still running
        if (!isFinished) {
            showUsingAnimation(useAnimation)
        }
    }
    @objc private func handleMinShowTimer(theTimer: Timer)                                          {
        hideUsingAnimation(useAnimation)
    }
    private func showUsingAnimation(_ animated: Bool)                                               {
        
        bezelView.layer.removeAllAnimations()
        backgroundView.layer.removeAllAnimations()
        hideDelayedTimer?.invalidate()
        setProgressDisplayLink(enabled: true)
        alpha = 1.1
        
        showStarted = Date()
        if (animated) {
            animate(in: true, type: animationType, completion: nil)
        } else {
            bezelView.alpha = opacity
            backgroundView.alpha = 1
        }
    }
    private func hideUsingAnimation(_ animated: Bool)                                               {
        if (animated && showStarted != nil) {
            showStarted = nil
            animate(in: false, type: animationType, completion: { (_) in
                self.done()
            })
        } else {
            showStarted = nil
            bezelView.alpha = 0.0
            backgroundView.alpha = 1.0
            self.done()
        }
    }
    private func animate(in show:Bool, type:MBProgressHUDAnimation, completion:((Bool)-> Void)?)    {
        // Automatically determine the correct zoom animation type
        
        var anim = type
        if type == .MBProgressHUDAnimationZoom {
            anim = show ? .MBProgressHUDAnimationZoomIn : .MBProgressHUDAnimationZoomOut
        }
        
        let small = CGAffineTransform(scaleX: 0.5, y: 0.5)
        let large = CGAffineTransform(scaleX: 1.5, y: 1.5)
        
        // Set starting state
        let bezelView = self.bezelView
        if (show && bezelView.alpha == 0 && anim == .MBProgressHUDAnimationZoomIn) {
            bezelView.transform = small
        } else if (show && bezelView.alpha == 0 && anim == .MBProgressHUDAnimationZoomOut) {
            bezelView.transform = large
        }
        
        // Perform animations
        let animations = {
            if (show) {
                bezelView.transform = CGAffineTransform.identity
            } else if (!show && anim == .MBProgressHUDAnimationZoomIn) {
                bezelView.transform = large
            } else if (!show && anim == .MBProgressHUDAnimationZoomOut) {
                bezelView.transform = small
            }
            bezelView.alpha = show ? self.opacity : 0
            self.backgroundView.alpha = show ? 1 : 0
        }

        UIView.animate(withDuration: 0.3, delay: 0,
                       usingSpringWithDamping: 1.0, initialSpringVelocity: 0,
                       options: .beginFromCurrentState,
                       animations: animations,
                       completion: completion)
    }
    private func done()                                                                             {
        hideDelayedTimer?.invalidate()
        setProgressDisplayLink(enabled: false)
        
        if (isFinished) {
            // If delegate was set make the callback
            alpha = 0.0
            if (removeFromSuperViewOnHide) {
                removeFromSuperview()
            }
        }
        if (completion != nil) {
            completion!()
        }
        if (delegate != nil) {
            delegate!.hudWasHidden(hud: self)
        }
    }
    
    // MARK -- Layout
    override func updateConstraints()                                                               {
        let metrics             = ["margin": margin] as [String: CGFloat]
        //
        // Remove existing constraints
        removeConstraints(constraints)
        topSpacer.removeConstraints(topSpacer.constraints)
        bottomSpacer.removeConstraints(bottomSpacer.constraints)
        if bezelConstraints.count>0 {
            bezelView.removeConstraints(bezelConstraints)
            bezelConstraints.removeAll()
        }
        //
        // Center bezel in container (self), applying the offset if set
        var centering = Array<NSLayoutConstraint>()
        centering.append(NSLayoutConstraint(item: bezelView, attribute: .centerX, relatedBy: .equal,
                                                       toItem: self, attribute: .centerX,
                                                       multiplier: 1, constant: offset.x))
        centering.append(NSLayoutConstraint(item: bezelView, attribute: .centerY, relatedBy: .equal,
                                                       toItem: self, attribute: .centerY,
                                                       multiplier: 1, constant: offset.y))
        applyPriority(priority: 998, toConstraints: centering)
        addConstraints(centering)
        //
        // Ensure minimum side margin is kept
        var sides = Array<NSLayoutConstraint>()
        sides.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "|-(>=margin)-[bezelView]-(>=margin)-|",
                                                                metrics: metrics, views: ["bezelView": bezelView]))
        sides.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=margin)-[bezelView]-(>=margin)-|",
                                                                metrics: metrics, views: ["bezelView": bezelView]))

        //applyPriority(priority: 999, toConstraints: sides)
        addConstraints(sides)
        //
        // Minimum bezel size, if set
        if !(minSize == CGSize.zero) {
            var bezelSize = Array<NSLayoutConstraint>()
            bezelSize.append(NSLayoutConstraint(item: bezelView, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil,
                                              attribute:.notAnAttribute, multiplier:1, constant: minSize.width))
            bezelSize.append(NSLayoutConstraint(item: bezelView, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil,
                                                attribute:.notAnAttribute, multiplier:1, constant: minSize.height))
            applyPriority(priority: 997, toConstraints: bezelSize)
            bezelConstraints.append(contentsOf: bezelSize)
        }
        //
        // Square aspect ratio, if set
        if (square) {
            let square = NSLayoutConstraint(item: bezelView, attribute: .height, relatedBy: .equal, toItem: bezelView,
                                            attribute: .width, multiplier: 1, constant: 0)
            
            square.priority = 997
            bezelConstraints.append(square)
        }
        
        // Top and bottom spacing
        topSpacer.addConstraint(NSLayoutConstraint(item: topSpacer, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil,
                                                   attribute: .notAnAttribute, multiplier: 1, constant: margin))
        bottomSpacer.addConstraint(NSLayoutConstraint(item: bottomSpacer, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil,
                                                      attribute: .notAnAttribute, multiplier: 1, constant: margin))

        // Top and bottom spaces should be equal
        bezelConstraints.append(NSLayoutConstraint(item: topSpacer, attribute: .height, relatedBy: .equal,
                                                   toItem: bottomSpacer, attribute: .height, multiplier: 1, constant: 0))
        
        //
        // Layout subviews in bezel
        paddingConstraints.removeAll()
        var subViews = [topSpacer, label, detailsLabel, button, bottomSpacer] as [UIView]
        if let indicatorView = indicator {
            subViews.insert(indicatorView, at: labelAboveIndicator ? 2 : 1)
        }
        let children = subViews as NSArray
        children.enumerateObjects({view, idx, stop in
            // Center in bezel
            bezelConstraints.append(NSLayoutConstraint(item: view, attribute: .centerX, relatedBy: .equal,
                                                       toItem: bezelView, attribute: .centerX, multiplier: 1, constant: 0))
            // Ensure the minimum edge margin is kept
            bezelConstraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "|-(>=margin)-[view]-(>=margin)-|",
                                                                               metrics: metrics, views: ["view": view]))
            // Element spacing
            if idx == 0 {
                // First, ensure spacing to bezel edge
                bezelConstraints.append(NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal,
                                                           toItem: bezelView, attribute: .top, multiplier: 1, constant: 0))
            } else if (idx == children.count - 1) {
                // Last, ensure spacing to bezel edge
                bezelConstraints.append(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal,
                                                           toItem: bezelView, attribute: .bottom, multiplier: 1, constant: 0))
            }
            if (idx > 0) {
                // Has previous
                let padding = NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal,
                                                 toItem: children[idx-1], attribute: .bottom, multiplier: 1, constant: 0)
                bezelConstraints.append(padding)
                paddingConstraints.append(padding)
            }
        })
        
        self.updatePaddingConstraints()
        bezelView.addConstraints(bezelConstraints)
        super.updateConstraints()
    }
    override func layoutSubviews()                                                                  {
        // There is no need to update constraints if they are going to
        // be recreated in super.layoutSubviews() due to needsUpdateConstraints being set.
        // This also avoids an issue on iOS 8, where updatePaddingConstraints
        // would trigger a zombie object access.
        if !needsUpdateConstraints() {
            self.updatePaddingConstraints()
        }
        super.layoutSubviews()
    }
    func updatePaddingConstraints()                                                                 {
        //
        // Set padding dynamically, depending on whether the view is visible or not
        var hasVisibleAncestors = false
        for padding in paddingConstraints {
            let firstView = padding.firstItem as! UIView
            let secondView = padding.secondItem as! UIView
            let firstVisible = !firstView.isHidden && !(firstView.intrinsicContentSize == CGSize.zero)
            let secondVisible = !secondView.isHidden && !(secondView.intrinsicContentSize == CGSize.zero)
            // Set if both views are visible or if there's a visible view on top that doesn't have padding
            // added relative to the current view yet
            padding.constant = (firstVisible && (secondVisible || hasVisibleAncestors)) ? MBPadding : 0
            hasVisibleAncestors = hasVisibleAncestors||secondVisible
        }
    }
    func applyPriority(priority: UILayoutPriority, toConstraints: [NSLayoutConstraint])             {
        for constraint in constraints {
            constraint.priority = priority
        }
    }
    
    // MARK -- Progress
    private func setProgressDisplayLink(enabled: Bool)                                              {
        // We're using CADisplayLink, because NSProgress can change very quickly and observing it may starve the main thread,
        // so we're refreshing the progress only every frame draw
        if (enabled && progressObject != nil) {
            // Only create if not already active.
            if (self.progressObjectDisplayLink == nil) {
                self.progressObjectDisplayLink = CADisplayLink(target:self, selector: #selector(updateProgressFromProgressObject))
            }
        } else {
            self.progressObjectDisplayLink = nil
        }
    }
    @objc private func updateProgressFromProgressObject()                                           {
        progress = CGFloat((progressObject?.fractionCompleted)!)
    }
    //
    // MARK -- Manual orientation change
    @objc private func statusBarOrientationDidChange(notification: NSNotification)                  {
        if self.superview != nil {
            updateForCurrentOrientation()
        }
    }
    private func updateForCurrentOrientation(animated: Bool = true)                                 {
        // Stay in sync with the superview
        if let superView = self.superview {
            self.bounds = superView.bounds
        }
    }
    
    // MARK - Utility
    private func dispatchOnMainThread(_ execute: @escaping ()->())                                  {
        if Thread.isMainThread {
            execute()
        } else {
            DispatchQueue.main.async(execute: execute)
        }
    }
    private func setupViews()                                                                       {
        let defaultColor = contentColor
        
        backgroundView.frame = bounds
        backgroundView.color = .clear
        backgroundView.alpha = 0
        addSubview(backgroundView)
        
        bezelView.translatesAutoresizingMaskIntoConstraints = false
        bezelView.layer.cornerRadius = 5.0
        bezelView.alpha = 0
        addSubview(bezelView)
        updateBezelMotionEffects()
        
        label.adjustsFontSizeToFitWidth = false
        label.textAlignment = .center
        label.textColor = defaultColor
        label.font = UIFont.boldSystemFont(ofSize: MBLabelFontSize)
        label.isOpaque = false
        label.backgroundColor = .clear
        
        detailsLabel.adjustsFontSizeToFitWidth = false
        detailsLabel.textAlignment = .center
        detailsLabel.textColor = defaultColor
        detailsLabel.numberOfLines = 0
        detailsLabel.font = UIFont.boldSystemFont(ofSize: MBDetailLabelFontSize)
        detailsLabel.isOpaque = false
        detailsLabel.backgroundColor = .clear
        
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: MBDetailLabelFontSize)
        button.setTitleColor(defaultColor, for: .normal)
        
        for view in [label, detailsLabel, button] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.setContentCompressionResistancePriority(998, for: .horizontal)
            view.setContentCompressionResistancePriority(998, for: .vertical)
            bezelView.addSubview(view)
        }
        
        topSpacer.translatesAutoresizingMaskIntoConstraints = false
        topSpacer.isHidden = true
        bezelView.addSubview(topSpacer)
        
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.isHidden = true
        bezelView.addSubview(bottomSpacer)
    }
    private func updateViews(forColor: UIColor)                                                     {
        label.textColor = forColor
        detailsLabel.textColor = forColor
        button.setTitleColor(forColor, for: .normal)
        
        var newColor = forColor
        if (activityIndicatorColor != nil) {
            newColor = activityIndicatorColor!
        }
        
        // UIAppearance settings are prioritized. If they are preset the set color is ignored.
        switch indicator {
        case is UIActivityIndicatorView:
            if #available(iOS 9.0, *) {
                let appearance = UIActivityIndicatorView.appearance(whenContainedInInstancesOf: [MBProgressHUD.self])
                if appearance.color == nil {
                    if let progress = indicator as? UIActivityIndicatorView {
                        progress.color = newColor
                    }
                }
            } else {
                // Fallback on earlier versions
                // TODO: Add back support for appearance for pre-OS 9?
                if let progress = indicator as? UIActivityIndicatorView {
                    progress.color = newColor
                }
            }
            
        case is MBRoundProgressView:
            if #available(iOS 9.0, *) {
                let appearance = MBRoundProgressView.appearance(whenContainedInInstancesOf: [MBProgressHUD.self])
                if let progress = indicator as? MBRoundProgressView {
                    if appearance.progressTintColor == nil {
                        progress.progressTintColor = newColor
                    }
                    if appearance.backgroundTintColor == nil {
                        progress.backgroundTintColor = newColor
                    }
                }
            } else {
                // Fallback on earlier versions
                // TODO: Add back support for appearance for pre-OS 9?
                if let progress = indicator as? MBRoundProgressView {
                    progress.progressTintColor = newColor
                    progress.backgroundTintColor = newColor
                }
            }
            
        case is MBBarProgressView:
            if #available(iOS 9.0, *) {
                let appearance = MBBarProgressView.appearance(whenContainedInInstancesOf: [MBProgressHUD.self])
                if let progress = indicator as? MBBarProgressView {
                    if appearance.progressColor == nil {
                        progress.progressColor = newColor
                    }
                    if appearance.lineColor == nil {
                        progress.lineColor = newColor
                    }
                }
            } else {
                // Fallback on earlier versions
                // TODO: Add back support for appearance for pre-OS 9?
                if let progress = indicator as? MBBarProgressView {
                    progress.progressColor = newColor
                    progress.lineColor = newColor
                }
            }

        default:
            let selector = NSSelectorFromString("setTintColor:" )
            if (indicator?.responds(to: selector))! {
                _ = indicator?.perform(selector, with: newColor)
            }
        }
    }
    private func updateBezelMotionEffects()                                                         {
        let selector = NSSelectorFromString("addMotionEffect:" )
        if bezelView.responds(to: selector) {
            
            if defaultMotionEffectsEnabled {
                let effectOffset:CGFloat = 10
                let effectX = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
                effectX.maximumRelativeValue = effectOffset
                effectX.minimumRelativeValue = -effectOffset
                
                let effectY = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
                effectY.maximumRelativeValue = effectOffset
                effectY.minimumRelativeValue = -effectOffset

                let group = UIMotionEffectGroup()
                group.motionEffects = [effectX, effectY]
                
                bezelView.addMotionEffect(group)
            } else {
                while bezelView.motionEffects.count>0 {
                    bezelView.removeMotionEffect(bezelView.motionEffects[0])
                }
            }
        }
    }
    private func updateIndicators()                                                                 {

        let isActivityIndicator = indicator is UIActivityIndicatorView
        let isRoundIndicator = indicator is MBRoundProgressView

        switch mode {
        case .MBProgressHUDModeIndeterminate:
            if (!isActivityIndicator) {
                // Update to indeterminate indicator
                indicator?.removeFromSuperview()
                let activity = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
                activity.startAnimating()
                bezelView.addSubview(activity)
                indicator = activity
            }
            
        case .MBProgressHUDModeDeterminateHorizontalBar:
            // Update to bar determinate indicator
            indicator?.removeFromSuperview()
            let progress = MBBarProgressView()
            bezelView.addSubview(progress)
            indicator = progress
            
        case .MBProgressHUDModeDeterminate, .MBProgressHUDModeAnnularDeterminate:
            if (!isRoundIndicator) {
                // Update to determinante indicator
                indicator?.removeFromSuperview()
                let progress = MBRoundProgressView()
                bezelView.addSubview(progress)
                indicator = progress
            }
            if let progress = indicator as? MBRoundProgressView {
                progress.isAnnular = mode == .MBProgressHUDModeAnnularDeterminate
            }
            
        case .MBProgressHUDModeCustomView:
            if customView != nil && customView != indicator {
                // Update custom view indicator
                indicator?.removeFromSuperview()
                indicator = customView
                bezelView.addSubview(indicator!)
                self.needsUpdateConstraints()
                self.setNeedsLayout()
                self.setNeedsDisplay()
            }
            
        case .MBProgressHUDModeText:
            indicator?.removeFromSuperview()
            indicator = nil
        }
        
        indicator?.translatesAutoresizingMaskIntoConstraints = false
       
        
        let selector = NSSelectorFromString("setProgress:" )
        if (indicator?.responds(to: selector))! {
            _ = indicator?.perform(selector, with: progress)
        }
    
        indicator?.setContentCompressionResistancePriority(998, for: .horizontal)
        indicator?.setContentCompressionResistancePriority(998, for: .vertical)
        
        updateViews(forColor: contentColor)
        setNeedsUpdateConstraints()
    }
    private func commonInit()                                                                       {
        
        autoresizingMask   = [.flexibleTopMargin,
                              .flexibleBottomMargin,
                              .flexibleLeftMargin,
                              .flexibleRightMargin]
        // Set some other properties now that 'super' has run.
        backgroundColor         = .clear
        alpha                   = 0.0
        isOpaque                = false
        rotationTransform       = CGAffineTransform.identity
        autoresizingMask        = [.flexibleWidth, .flexibleHeight]

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(statusBarOrientationDidChange),
                                               name: .UIDeviceOrientationDidChange,
                                               object: nil)
        setupViews()
        updateIndicators()
        updateViews(forColor: contentColor)
    }

    // MARK -- Utility sub-classes
    class MBRoundProgressView: UIView                                                               {
        var progress:CGFloat {
            didSet {
                setNeedsDisplay()
            }
        }
        var progressTintColor: UIColor? {
            didSet {
                setNeedsDisplay()
            }
        }
        var backgroundTintColor: UIColor? {
            didSet {
                setNeedsDisplay()
            }
        }

        /**
         * Display mode - false = round or true = annular. Defaults to round.
         */
        var isAnnular: Bool {
            didSet {
                setNeedsDisplay()
            }
        }

        // MARK --  Lifecycle
        override init(frame: CGRect)                                                                {
            self.progress               = 0
            self.progressTintColor      = .white
            self.backgroundTintColor    = UIColor.white.withAlphaComponent(0.1)
            self.isAnnular              = false
            
            super.init(frame: frame)
            
            backgroundColor             = .clear
            isOpaque                    = false
        }
        required init?(coder aDecoder: NSCoder)                                                     {
            self.progress               = 0
            self.progressTintColor      = .white
            self.backgroundTintColor    = UIColor.white.withAlphaComponent(0.1)
            self.isAnnular              = false

            super.init(coder: aDecoder)
            
            backgroundColor             = .clear
            isOpaque                    = false
        }
        
        // MARK -- Drawing
        override func draw(_ rect:CGRect)                                                           {
            
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            if (isAnnular) {
                // Draw background
                let lineWidth:CGFloat = 2.0
                let processBackgroundPath = UIBezierPath()
                processBackgroundPath.lineWidth = lineWidth
                processBackgroundPath.lineCapStyle = .butt
                let radius = (bounds.size.width - lineWidth)/2
                let startAngle = -CGFloat.pi / 2 // 90 degrees
                var endAngle = 2 * CGFloat.pi + startAngle
                processBackgroundPath.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                backgroundTintColor?.set()
                processBackgroundPath.stroke()
                // Draw progress
                let processPath = UIBezierPath()
                processPath.lineCapStyle = .square
                processPath.lineWidth = lineWidth
                endAngle = progress * 2 * CGFloat.pi + startAngle
                processPath.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                progressTintColor?.set()
                processPath.stroke()
            } else {
                let lineWidth:CGFloat = 2
                let allRect = self.bounds
                let circleRect = allRect.insetBy(dx: lineWidth/2, dy: lineWidth/2)

                let context = UIGraphicsGetCurrentContext()
                
                // Draw background
                progressTintColor?.setStroke()
                backgroundTintColor?.setFill()
                context?.setLineWidth(lineWidth)
                context?.strokeEllipse(in: circleRect)
                
                // Draw progress
                let center = CGPoint(x: allRect.size.width / 2, y: allRect.size.height / 2)
                let startAngle = -CGFloat.pi/2
                let processPath = UIBezierPath()
                processPath.lineCapStyle = .butt
                processPath.lineWidth = lineWidth * 2
                let radius = bounds.width / 2 - processPath.lineWidth / 2
                let endAngle = progress * 2 * CGFloat.pi + startAngle
                processPath.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                // Ensure that we don't get color overlaping when _progressTintColor alpha < 1.f.
                context?.setBlendMode(.copy)
                progressTintColor?.set()
                processPath.stroke()
            }
        }
    }
    class MBBarProgressView: UIView                                                                 {
        /**
         * Progress (0.0 to 1.0)
         */
        var progress:Double {
            didSet {
                setNeedsDisplay()
            }
        }
        /**
         * Bar border line color. Defaults to .white
         */
        var lineColor:UIColor? {
            didSet {
                setNeedsDisplay()
            }
        }
        /**
         * Bar background color. Defaults to .clear
         */
        var progressRemainingColor:UIColor {
            didSet {
                setNeedsDisplay()
            }
        }
        /**
         * Bar progress color. Defaults to .white
         */
        var progressColor:UIColor? {
            didSet {
                setNeedsDisplay()
            }
        }
        
        // MARK --  Lifecycle
        override init(frame: CGRect)                                                                {
            self.lineColor                  = .white
            self.progressColor              = .white
            self.progressRemainingColor     = .clear
            self.progress                   = 0
            
            super.init(frame: frame)
            
            backgroundColor                 = .clear
            isOpaque                        = false
        }
        required init?(coder aDecoder: NSCoder)                                                     {
            self.lineColor                  = .white
            self.progressColor              = .white
            self.progressRemainingColor     = .clear
            self.progress                   = 0
            
            super.init(coder: aDecoder)
            
            backgroundColor                 = .clear
            isOpaque                        = false
        }
        
        override var intrinsicContentSize: CGSize                                                   {
            return CGSize(width: 120, height: 10)
        }
        override func draw(_ rect: CGRect)                                                          {
            let context = UIGraphicsGetCurrentContext()
            
            lineColor?.setStroke()
            progressRemainingColor.setFill()
            context?.setLineWidth(2)
            
            var radius = rect.size.height / 2 - 2

            let makePath = {
                context?.move(to: CGPoint(x:2, y: rect.size.height/2))
                context?.addArc(tangent1End: CGPoint(x:2, y:2),
                                tangent2End: CGPoint(x:radius, y:radius+2), radius: radius)
                context?.addLine(to: CGPoint(x: rect.size.width - radius - 2, y: 2))
                context?.addArc(tangent1End: CGPoint(x:rect.size.width - 2, y:2),
                                tangent2End: CGPoint(x:rect.size.width - 2, y:rect.size.height / 2), radius: radius)
                context?.addArc(tangent1End: CGPoint(x:rect.size.width - 2, y:rect.size.height - 2),
                                tangent2End: CGPoint(x:rect.size.width - radius - 2, y:rect.size.height - 2), radius: radius)
                context?.addLine(to: CGPoint(x: radius + 2, y: rect.size.height - 2))
                context?.addArc(tangent1End: CGPoint(x:2, y:rect.size.height - 2),
                                tangent2End: CGPoint(x:2, y:rect.size.height/2), radius: radius)
                
            }
            // Draw background
            makePath()
            context?.fillPath()
            
            // Draw border
            makePath()
            context?.strokePath()
            
            progressColor?.setFill()
            radius -= 2
            let amount = CGFloat(progress) * rect.size.width
            
            if (amount >= radius + 4 && amount <= (rect.size.width - radius - 4)) {
                // Progress in the middle area
                context?.move(to: CGPoint(x: 4, y:rect.size.height/2))
                context?.addArc(tangent1End: CGPoint(x:4, y:4),
                                tangent2End: CGPoint(x:radius+4, y:4), radius: radius)
                context?.addLine(to: CGPoint(x: amount, y: 4))
                context?.addLine(to: CGPoint(x: amount, y: radius + 4))
                
                context?.move(to: CGPoint(x: 4, y: rect.size.height/2))
                context?.addArc(tangent1End: CGPoint(x:4, y:rect.size.height - 4),
                                tangent2End: CGPoint(x:radius+4, y: rect.size.height - 4), radius: radius)
                context?.addLine(to: CGPoint(x: amount, y: rect.size.height - 4))
                context?.addLine(to: CGPoint(x: amount, y: radius + 4))

                context?.fillPath()
            } else if (amount > radius + 4) {
                // Progress in the right arc

                let x = amount - (rect.size.width - radius - 4)
                
                context?.move(to: CGPoint(x: 4, y:rect.size.height/2))
                context?.addArc(tangent1End: CGPoint(x:4, y:4),
                                tangent2End: CGPoint(x:radius+4, y:4), radius: radius)
                context?.addLine(to: CGPoint(x: rect.size.width - radius - 4, y: 4))
                
                var angle = CGFloat(-acos(x/radius))
                context?.addArc(center: CGPoint(x: rect.size.width - radius - 4, y: rect.size.height/2),
                                radius: radius, startAngle: CGFloat.pi, endAngle: angle, clockwise: false)
                context?.addLine(to: CGPoint(x: amount, y: rect.size.height/2))
                context?.move(to: CGPoint(x: 4, y: rect.size.height/2))
                context?.addArc(tangent1End: CGPoint(x: 4, y: rect.size.height - 4),
                                tangent2End: CGPoint(x: radius + 4, y: rect.size.height - 4), radius: radius)
                context?.addLine(to: CGPoint(x: rect.size.width - radius - 4, y: rect.size.height - 4))
                angle = acos(x/radius)
                context?.addArc(center: CGPoint(x: rect.size.width - radius - 4, y: rect.size.height/2),
                                radius: radius, startAngle: -CGFloat.pi, endAngle: angle, clockwise: true)
                context?.addLine(to: CGPoint(x: amount, y: rect.size.height/2))
                context?.fillPath()
            
            } else if (amount < radius + 4 && amount > 0) {
                // Progress is in the left arc
                context?.move(to: CGPoint(x: 4, y:rect.size.height/2))
                context?.addArc(tangent1End: CGPoint(x:4, y:4),
                                tangent2End: CGPoint(x:radius+4, y:4), radius: radius)
                context?.addLine(to: CGPoint(x: radius + 4, y: rect.size.height/2))

                context?.move(to: CGPoint(x: 4, y: rect.size.height/2))
                context?.addArc(tangent1End: CGPoint(x:4, y:rect.size.height - 4),
                                tangent2End: CGPoint(x:radius+4, y: rect.size.height - 4), radius: radius)
                context?.addLine(to: CGPoint(x: radius + 4, y: rect.size.height / 4))

                context?.fillPath()
            }
        }
    }
    class MBBackgroundView : UIView                                                                 {
    
        /**
         * The background color or the blur tint color.
         */
        var color: UIColor {
            didSet {
                self.backgroundColor = self.color
                if self.color == .clear {
                    effectView.removeFromSuperview()
                } else {
                    addSubview(effectView)
                }
            }
        }
        private var effectView: UIVisualEffectView
        // MARK --  Lifecycle
        override init(frame: CGRect)                                                                {
            if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
                color = UIColor(white: 0.8, alpha: 0.6)
            } else {
                color = UIColor(white: 0.95, alpha: 0.6)
            }
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            
            super.init(frame: frame)

            clipsToBounds = true
            addSubview(effectView)
            effectView.frame = bounds
            effectView.autoresizingMask = [.flexibleHeight, .flexibleWidth ]
            backgroundColor = color
            layer.allowsGroupOpacity = false
        }
        required init?(coder aDecoder: NSCoder)                                                     {
            if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
                color = UIColor(white: 0.8, alpha: 0.6)
            } else {
                color = UIColor(white: 0.95, alpha: 0.6)
            }
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))

            super.init(coder: aDecoder)
            
            clipsToBounds = true
            addSubview(effectView)
            effectView.frame = bounds
            effectView.autoresizingMask = [.flexibleHeight, .flexibleWidth ]
            backgroundColor = color
            layer.allowsGroupOpacity = false
        }
        override var intrinsicContentSize: CGSize                                                   {
            return CGSize.zero
        }
    }
    class MBProgressHUDRoundedButton: UIButton                                                      {
        
        // MARK -- Lifecycle
        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.borderWidth = 1.0
        }
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            layer.borderWidth = 1.0
        }

        // MARK -- Layout
        override func layoutSubviews() {
            super.layoutSubviews()
            // Fully rounded corners
            self.layer.cornerRadius = ceil(self.bounds.height / 2)
        }
        override var intrinsicContentSize: CGSize {
            // Only show if we have associated control events
            if allControlEvents.rawValue == 0 {
                return CGSize.zero
            }
            var size = super.intrinsicContentSize
            // Add some side padding
            size.width += 20
            return size
        }
        
        // MARK -- Color
        override func setTitleColor(_ color: UIColor?, for state: UIControlState) {
            super.setTitleColor(color, for: state)
            // Update related colors
            if isHighlighted {
                isHighlighted = true
            }
            layer.borderColor = color?.cgColor
        }
        override var isHighlighted: Bool {
            didSet {
                let baseColor = self.titleColor(for: .selected)
                backgroundColor = isHighlighted ? baseColor?.withAlphaComponent(0.1) : .clear
            }
        }
    }
}
