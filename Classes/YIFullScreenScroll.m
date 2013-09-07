//
//  YIFullScreenScroll.m
//  YIFullScreenScroll
//
//  Created by Yasuhiro Inami on 12/06/03.
//  Copyright (c) 2012 Yasuhiro Inami. All rights reserved.
//

#import "YIFullScreenScroll.h"
#import <objc/runtime.h>
#import "ViewUtils.h"

#define IS_PORTRAIT             UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)
#define IS_IOS_AT_LEAST(ver)    ([[[UIDevice currentDevice] systemVersion] compare:ver] != NSOrderedAscending)

#define MAX_SHIFT_PER_SCROLL    10  // used when _shouldHideUIBarsGradually=YES

static char __fullScreenScrollContext;


#pragma mark -


@implementation UINavigationBar (YIFullScreenScroll)

- (void)setTranslucentIfNeeded:(BOOL)translucent
{
    if (IS_IOS_AT_LEAST(@"7.0")) return;
    
    self.translucent = translucent;
}

@end


@implementation UIToolbar (YIFullScreenScroll)

- (void)setTranslucentIfNeeded:(BOOL)translucent
{
    if (IS_IOS_AT_LEAST(@"7.0")) return;
    
    self.translucent = translucent;
}

@end


#pragma mark -


@interface YIFullScreenScroll ()

@property (nonatomic) BOOL isShowingUIBars;
@property (nonatomic) BOOL isViewVisible;
@property (nonatomic) BOOL hasViewAppearedBefore;

@end


@implementation YIFullScreenScroll
{
    __weak UINavigationController* _navigationController;
    __weak UITabBarController*     _tabBarController;
    
    UIImageView*        _customNavBarBackground;
    UIImageView*        _customToolbarBackground;
    
    UIEdgeInsets        _defaultScrollIndicatorInsets;
    
    CGFloat             _defaultNavBarTop;
    CGFloat             _additionalNavBarShiftForIOS7StatusBar;
    
    BOOL _areUIBarBackgroundsReady;
    
    BOOL _isObservingNavBar;
    BOOL _isObservingToolbar;
    
    BOOL _shouldUseCustomBackground;
}

#pragma mark -

#pragma mark Init/Dealloc

- (id)initWithViewController:(UIViewController*)viewController
                  scrollView:(UIScrollView*)scrollView
{
    BOOL shouldUseCustomBackground = !IS_IOS_AT_LEAST(@"7.0");
    
    return [self initWithViewController:viewController
                             scrollView:scrollView
              shouldUseCustomBackground:shouldUseCustomBackground];
}

- (id)initWithViewController:(UIViewController*)viewController
                  scrollView:(UIScrollView*)scrollView
   shouldUseCustomBackground:(BOOL)shouldUseCustomBackground
{
    self = [super init];
    if (self) {
        
        _viewController = viewController;
        _shouldUseCustomBackground = shouldUseCustomBackground;
        
        _additionalNavBarShiftForIOS7StatusBar = IS_IOS_AT_LEAST(@"7.0") ? 20 : 0;
        
        _shouldShowUIBarsOnScrollUp = YES;
        
        _shouldHideNavigationBarOnScroll = YES;
        _shouldHideToolbarOnScroll = YES;
        _shouldHideTabBarOnScroll = YES;
        
        _shouldHideUIBarsGradually = YES;
        _shouldHideUIBarsWhenNotDragging = NO;
        _shouldHideUIBarsWhenContentHeightIsTooShort = NO;
        
        _additionalOffsetYToStartHiding = 0.0;
        _additionalOffsetYToStartShowing = 0.0;
        
        _enabled = YES; // don't call self.enabled = YES
        
        _layoutingUIBarsEnabled = YES;
        
        self.scrollView = scrollView;
        
    }
    return self;
}

- (void)dealloc
{
    if (self.isViewVisible) {
        self.enabled = NO;
    }
    
    self.scrollView = nil;
}

#pragma mark -

#pragma mark Accessors

- (void)setScrollView:(UIScrollView *)scrollView
{
    if (scrollView != _scrollView) {
        
        if (_scrollView) {
            [_scrollView removeObserver:self forKeyPath:@"contentOffset" context:&__fullScreenScrollContext];
            
            [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
        }
        
        _scrollView = scrollView;
        
        if (_scrollView) {
            [_scrollView addObserver:self forKeyPath:@"contentOffset" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&__fullScreenScrollContext];
            
            //
            // observe willEnterForeground to properly set both navBar & tabBar
            // (fixes https://github.com/inamiy/YIFullScreenScroll/issues/5)
            //
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(onWillEnterForegroundNotification:)
                                                         name:UIApplicationWillEnterForegroundNotification
                                                       object:nil];
            
            _defaultScrollIndicatorInsets = _scrollView.scrollIndicatorInsets;
        }
        
    }
}

- (void)setEnabled:(BOOL)enabled
{
    if (enabled != _enabled) {
        
        if (enabled) {
            [self _setupUIBarBackgrounds];
            [self _layoutContainerViewExpanding:YES];
            
            // set YES after setup finished so that observing contentOffset will be safely handled
            _enabled = YES;
        }
        else {
            // show before setting _enabled=NO
            [self showUIBarsAnimated:NO];
            
            // set NO before teardown starts so that observing contentOffset will be safely handled
            _enabled = NO;
            
            [self _teardownUIBarBackgrounds];
            [self _layoutContainerViewExpanding:NO];
        }
        
    }
}

#pragma mark -

#pragma mark Public

- (void)viewWillAppear:(BOOL)animated
{
    self.isViewVisible = NO;
    
    if (self.enabled) {
        
        // if no modal or 1st viewWillAppear
        if (!_viewController.presentedViewController || !self.hasViewAppearedBefore) {
            
            // evaluate defaultNavBarTop when view is loaded
            _defaultNavBarTop = self.navigationBar.top;
            
            //
            // comment-out:
            //
            // Always call _setupUIBarBackgrounds when enabled,
            // since there is a case where modal is presented in other presentingViewController
            // but is suddenly changed to _viewController e.g. via tabBar-switching.
            //
            //[self _setupUIBarBackgrounds];
        }
        [self _setupUIBarBackgrounds];
        
        // show after modal-dismiss too, since navBar/toolbar will automatically become visible but tabBar doesn't
        [self showUIBarsAnimated:NO];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    if (self.enabled) {
        // NOTE: required for tabBarController layouting
        [self _layoutContainerViewExpanding:YES];
    }
    
    self.isViewVisible = YES;   // set YES after layouting
    self.hasViewAppearedBefore = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    self.isViewVisible = NO;
    
    if (self.enabled) {
        
        // if no modal
        if (!_viewController.presentedViewController) {
            [self _teardownUIBarBackgrounds];
            [self showUIBarsAnimated:NO];
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    self.isViewVisible = NO;
    
    if (self.enabled) {
        [self _layoutContainerViewExpanding:NO];
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self showUIBarsAnimated:NO];
}

- (void)showUIBarsAnimated:(BOOL)animated
{
    [self showUIBarsAnimated:animated completion:NULL];
}

- (void)showUIBarsAnimated:(BOOL)animated completion:(void (^)(BOOL finished))completion
{
    if (!self.enabled) return;
    
    self.isShowingUIBars = YES;
    
    if (animated) {
        
        __weak typeof(self) weakSelf = self;
        
        [UIView animateWithDuration:0.1 animations:^{
            
            // pretend to scroll up by 50 pt which is longer than navBar/toolbar/tabBar height
            [weakSelf _layoutUIBarsWithDeltaY:-50-_additionalNavBarShiftForIOS7StatusBar];
            
        } completion:^(BOOL finished) {
            
            weakSelf.isShowingUIBars = NO;
            
            if (completion) {
                completion(finished);
            }
            
        }];
    }
    else {
        [self _layoutUIBarsWithDeltaY:-50-_additionalNavBarShiftForIOS7StatusBar];
        self.isShowingUIBars = NO;
    }
    
}

#pragma mark -

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &__fullScreenScrollContext) {
        
        if ([keyPath isEqualToString:@"tintColor"]) {
            
            // comment-out (should tintColor even when disabled)
            //if (!self.enabled) return;
            
            [self _removeCustomBackgroundOnUIBar:object];
            [self _addCustomBackgroundOnUIBar:object];
            
        }
        else if ([keyPath isEqualToString:@"contentOffset"]) {
            
            if (!self.enabled) return;
            if (!self.layoutingUIBarsEnabled) return;
            if (!self.isViewVisible) return;
            
            CGPoint newPoint = [change[NSKeyValueChangeNewKey] CGPointValue];
            CGPoint oldPoint = [change[NSKeyValueChangeOldKey] CGPointValue];
            
            CGFloat deltaY = newPoint.y - oldPoint.y;
            
            [self _layoutUIBarsWithDeltaY:deltaY];
            
        }
        
    }
}

#pragma mark Notifications

- (void)onWillEnterForegroundNotification:(NSNotification*)notification
{
    [self showUIBarsAnimated:NO];
}

#pragma mark -

#pragma mark UIBars

- (UINavigationController*)navigationController
{
    if (!_navigationController) {
        _navigationController = _viewController.navigationController;
    }
    return _navigationController;
}

//
// NOTE: weakly referencing tabBarController is important to safely reset its size on viewDidDisappear
// (fixes https://github.com/inamiy/YIFullScreenScroll/issues/7#issuecomment-17991653)
//
- (UITabBarController*)tabBarController
{
    if (!_tabBarController) {
        _tabBarController = _viewController.tabBarController;
    }
    return _tabBarController;
}

- (UINavigationBar*)navigationBar
{
    return self.navigationController.navigationBar;
}

- (UIToolbar*)toolbar
{
    return self.navigationController.toolbar;
}

- (UITabBar*)tabBar
{
    return self.tabBarController.tabBar;
}

- (BOOL)isNavigationBarExisting
{
    UINavigationBar* navBar = self.navigationBar;
    return navBar && navBar.superview && !navBar.hidden && !self.navigationController.navigationBarHidden;
}

- (BOOL)isToolbarExisting
{
    UIToolbar* toolbar = self.toolbar;
    return toolbar && toolbar.superview && !toolbar.hidden && !self.navigationController.toolbarHidden;
}

- (BOOL)isTabBarExisting
{
    UITabBar* tabBar = self.tabBar;
    return tabBar && tabBar.superview && !tabBar.hidden;
}

#pragma mark -

#pragma mark Layout

- (void)_layoutUIBarsWithDeltaY:(CGFloat)deltaY
{
    if (!self.enabled) return;
    if (!self.layoutingUIBarsEnabled) return;
    if (deltaY == 0.0) return;
    
    BOOL canLayoutUIBars = YES;
    
    UIScrollView* scrollView = self.scrollView;
    
    if (!self.isShowingUIBars) {
        
        BOOL isContentHeightTooShortToLayoutUIBars = (scrollView.contentSize.height+scrollView.contentInset.bottom < scrollView.frame.size.height);
        BOOL isContentHeightTooShortToLimitShiftPerScroll = (scrollView.contentSize.height+scrollView.contentInset.bottom < scrollView.frame.size.height+100);
        
        // don't layout UIBars if content is too short (adjust scrollIndicators only)
        // (skip if _viewController.view is not visible yet, which tableView.contentSize.height is normally 0)
        if (self.isViewVisible && !self.shouldHideUIBarsWhenContentHeightIsTooShort && isContentHeightTooShortToLayoutUIBars) {
            canLayoutUIBars = NO;
        }
        
        CGFloat offsetY = scrollView.contentOffset.y;
        
        CGFloat maxOffsetY = scrollView.contentSize.height+scrollView.contentInset.bottom-scrollView.frame.size.height;
        
        //
        // Keep hiding UI-bars when:
        // 1. scroll reached bottom
        // 2. shouldShowUIBarsOnScrollUp = NO & scrolling up (until offset.y reaches either top or additionalOffsetYToStartShowing)
        //
        if ((offsetY >= maxOffsetY) ||
            (!self.shouldShowUIBarsOnScrollUp && deltaY < 0 && offsetY-self.additionalOffsetYToStartShowing > 0)) {
            
            deltaY = fabs(deltaY);
        }
        // always show UI-bars when scrolling up too high
        else if (offsetY-self.additionalOffsetYToStartHiding <= -scrollView.contentInset.top) {
            deltaY = -fabs(deltaY);
        }
        // adjust deltaY if prev-scroll-position was up too high, but now it is not (= about to start hiding)
        else if (offsetY-deltaY-self.additionalOffsetYToStartHiding <= -scrollView.contentInset.top) {
            deltaY = offsetY-self.additionalOffsetYToStartHiding+scrollView.contentInset.top;
        }
        
        // if there is enough scrolling distance, use MAX_SHIFT_PER_SCROLL for smoother shifting
        CGFloat maxShiftPerScroll = CGFLOAT_MAX;
        if (_shouldHideUIBarsGradually && !isContentHeightTooShortToLimitShiftPerScroll) {
            maxShiftPerScroll = MAX_SHIFT_PER_SCROLL;
        }
        
        deltaY = MIN(deltaY, maxShiftPerScroll);
        
        // NOTE: don't limit deltaY in case of navBar being partially hidden & scrolled-up very fast
        if (offsetY > 0) {
            deltaY = MAX(deltaY, -maxShiftPerScroll);
        }
    }
    
    if (deltaY == 0.0) return;
    
    // return if user hasn't dragged but trying to hide UI-bars (e.g. orientation change)
    if (deltaY > 0 && !self.scrollView.isDragging && !self.shouldHideUIBarsWhenNotDragging) return;
    
    // navbar
    UINavigationBar* navBar = self.navigationBar;
    BOOL isNavigationBarExisting = self.isNavigationBarExisting;
    if (isNavigationBarExisting && _shouldHideNavigationBarOnScroll) {
        if (canLayoutUIBars) {
            navBar.top = MIN(MAX(navBar.top-deltaY, _defaultNavBarTop-navBar.height-_additionalNavBarShiftForIOS7StatusBar), _defaultNavBarTop);
        }
    }
    
    // toolbar
    UIToolbar* toolbar = self.toolbar;
    BOOL isToolbarExisting = self.isToolbarExisting;
    CGFloat toolbarSuperviewHeight = 0;
    if (isToolbarExisting && _shouldHideToolbarOnScroll) {
        // NOTE: if navC.view.superview == window, navC.view won't change its frame and only rotate-transform
        if ([toolbar.superview.superview isKindOfClass:[UIWindow class]]) {
            toolbarSuperviewHeight = IS_PORTRAIT ? toolbar.superview.height : toolbar.superview.width;
        }
        else {
            toolbarSuperviewHeight = toolbar.superview.height;
        }
        
        if (canLayoutUIBars) {
            toolbar.top = MIN(MAX(toolbar.top+deltaY, toolbarSuperviewHeight-toolbar.height), toolbarSuperviewHeight);
        }
    }
    
    // tabBar
    UITabBar* tabBar = self.tabBar;
    BOOL isTabBarExisting = self.isTabBarExisting;
    CGFloat tabBarSuperviewHeight = 0;
    if (isTabBarExisting && _shouldHideTabBarOnScroll) {
        if ([tabBar.superview.superview isKindOfClass:[UIWindow class]]) {
            tabBarSuperviewHeight = IS_PORTRAIT ? tabBar.superview.height : tabBar.superview.width;
        }
        else {
            tabBarSuperviewHeight = tabBar.superview.height;
        }
        
        if (canLayoutUIBars) {
            tabBar.top = MIN(MAX(tabBar.top+deltaY, tabBarSuperviewHeight-tabBar.height), tabBarSuperviewHeight);
        }
    }
    
    if (self.enabled && self.isViewVisible) {
        
        // scrollIndicatorInsets
        UIEdgeInsets insets = scrollView.scrollIndicatorInsets;
        if (isNavigationBarExisting && _shouldHideNavigationBarOnScroll) {
            insets.top = navBar.bottom-_defaultNavBarTop+_additionalNavBarShiftForIOS7StatusBar;
        }
        insets.bottom = 0;
        if (isToolbarExisting && _shouldHideToolbarOnScroll) {
            insets.bottom += toolbarSuperviewHeight-toolbar.top;
        }
        if (isTabBarExisting && _shouldHideTabBarOnScroll) {
            insets.bottom += tabBarSuperviewHeight-tabBar.top;
        }
        scrollView.scrollIndicatorInsets = insets;
        
        // delegation
        if (canLayoutUIBars) {
            if ([_delegate respondsToSelector:@selector(fullScreenScrollDidLayoutUIBars:)]) {
                [_delegate fullScreenScrollDidLayoutUIBars:self];
            }
        }
    }
}

- (void)_layoutContainerViewExpanding:(BOOL)expanding
{
    // tabBarController layouting is no longer needed from iOS7
    if (IS_IOS_AT_LEAST(@"7.0")) return;
    
    // toolbar (iOS5 fix which doesn't re-layout when translucent is set)
    if (_shouldHideToolbarOnScroll && self.isToolbarExisting) {
        BOOL toolbarHidden = self.navigationController.toolbarHidden;
        [self.navigationController setToolbarHidden:!toolbarHidden];
        [self.navigationController setToolbarHidden:toolbarHidden];
    }
    
    // tabBar
    if (_shouldHideTabBarOnScroll && self.isTabBarExisting) {
        
        UIView* tabBarTransitionView = [self.tabBarController.view.subviews objectAtIndex:0];
        
        if (expanding) {
            tabBarTransitionView.frame = self.tabBarController.view.bounds;
            
            // add extra contentInset.bottom for tabBar-expansion
            UIEdgeInsets insets = _scrollView.contentInset;
            insets.bottom = self.tabBar.frame.size.height;
            _scrollView.contentInset = insets;
            
        }
        else {
            UITabBar* tabBar = self.tabBar;
            
            CGRect frame = self.tabBarController.view.bounds;
            frame.size.height -= tabBar.height;
            tabBarTransitionView.frame = frame;
            
            // scrollIndicatorInsets will be modified when tabBarTransitionView shrinks, so reset it here.
            _scrollView.scrollIndicatorInsets = _defaultScrollIndicatorInsets;
            
            UIEdgeInsets insets = _scrollView.contentInset;
            insets.bottom = 0;
            _scrollView.contentInset = insets;
        }
    }
    
}

#pragma mark -

#pragma mark Custom Background

- (void)_setupUIBarBackgrounds
{
    if (_areUIBarBackgroundsReady) return;
    
    if (self.navigationController) {
        
        UINavigationBar* navBar = self.navigationBar;
        UIToolbar* toolbar = self.toolbar;
        
        // navBar
        if (_shouldHideNavigationBarOnScroll) {
            
            // hide original background & add opaque custom one
            if (_shouldUseCustomBackground) {
                [self _addCustomBackgroundOnUIBar:navBar];
                
                if (!_isObservingNavBar) {
                    [navBar addObserver:self forKeyPath:@"tintColor" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&__fullScreenScrollContext];
                    _isObservingNavBar = YES;
                }
            }
            navBar.translucentIfNeeded = YES;
        }
        else {
            navBar.translucentIfNeeded = NO;
        }
        
        // toolbar
        if (_shouldHideToolbarOnScroll) {
            
            // hide original background & add opaque custom one
            if (_shouldUseCustomBackground) {
                [self _addCustomBackgroundOnUIBar:toolbar];
                
                if (!_isObservingToolbar) {
                    [toolbar addObserver:self forKeyPath:@"tintColor" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&__fullScreenScrollContext];
                    _isObservingToolbar = YES;
                }
                
            }
            toolbar.translucentIfNeeded = YES;
        }
        else {
            toolbar.translucentIfNeeded = NO;
        }
    }
    
    _areUIBarBackgroundsReady = YES;
}

- (void)_teardownUIBarBackgrounds
{
    if (!_areUIBarBackgroundsReady) return;
    
    if (_shouldUseCustomBackground) {
        [self _removeCustomBackgroundOnUIBar:self.navigationBar];
        [self _removeCustomBackgroundOnUIBar:self.toolbar];
        
        if (_isObservingNavBar) {
            [self.navigationBar removeObserver:self forKeyPath:@"tintColor" context:&__fullScreenScrollContext];
            _isObservingNavBar= NO;
        }
        if (_isObservingToolbar) {
            [self.toolbar removeObserver:self forKeyPath:@"tintColor" context:&__fullScreenScrollContext];
            _isObservingToolbar = NO;
        }
    }
    
    self.navigationBar.translucentIfNeeded = NO;
    self.toolbar.translucentIfNeeded = NO;
    
    _areUIBarBackgroundsReady = NO;
}

- (BOOL)_hasCustomBackgroundOnUIBar:(UIView*)bar
{
    if ([bar.subviews count] <= 1) return NO;
    
    UIView* subview1 = [bar.subviews objectAtIndex:1];
    
    if (![subview1 isKindOfClass:[UIImageView class]]) return NO;
    
    if (CGRectEqualToRect(bar.bounds, subview1.frame)) {
        return YES;
    }
    else {
        return NO;
    }
}

// removes old & add new custom background for UINavigationBar/UIToolbar
- (void)_addCustomBackgroundOnUIBar:(UIView*)bar
{
    if (!bar) return;
    
    BOOL isUIBarHidden = NO;
    
    // temporarilly set translucent=NO to copy custom backgroundImage
    if (bar == self.navigationBar) {
        [_customNavBarBackground removeFromSuperview];
        self.navigationBar.translucentIfNeeded = NO;
        
        // temporarilly show navigationBar to copy backgroundImage safely
        isUIBarHidden = self.navigationController.navigationBarHidden;
        if (isUIBarHidden) {
            [self.navigationController setNavigationBarHidden:NO];
        }
    }
    else if (bar == self.toolbar) {
        [_customToolbarBackground removeFromSuperview];
        self.toolbar.translucentIfNeeded = NO;
        
        // temporarilly show toolbar to copy backgroundImage safely
        isUIBarHidden = self.navigationController.toolbarHidden;
        if (isUIBarHidden) {
            [self.navigationController setToolbarHidden:NO];
        }
    }
    
    // create custom background
    UIImageView* originalBackground = [bar.subviews objectAtIndex:0];
    UIImageView* customBarImageView = [[UIImageView alloc] initWithImage:[originalBackground.image copy]];
    [bar insertSubview:customBarImageView atIndex:0];
    
    originalBackground.hidden = YES;
    customBarImageView.opaque = YES;
    customBarImageView.frame = originalBackground.frame;
    
    // NOTE: auto-resize when tintColored & rotated
    customBarImageView.autoresizingMask = originalBackground.autoresizingMask | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    if (bar == self.navigationBar) {
        self.navigationBar.translucentIfNeeded = YES;
        _customNavBarBackground = customBarImageView;
        
        // hide navigationBar if needed
        if (isUIBarHidden) {
            [self.navigationController setNavigationBarHidden:YES];
        }
    }
    else if (bar == self.toolbar) {
        self.toolbar.translucentIfNeeded = YES;
        _customToolbarBackground = customBarImageView;
        
        // hide toolbar if needed
        if (isUIBarHidden) {
            [self.navigationController setToolbarHidden:YES];
        }
    }
}

- (void)_removeCustomBackgroundOnUIBar:(UIView*)bar
{
    if (bar == self.navigationBar) {
        [_customNavBarBackground removeFromSuperview];
    }
    else if (bar == self.toolbar) {
        [_customToolbarBackground removeFromSuperview];
    }
    else {
        return;
    }
    
    UIImageView* originalBackground = [bar.subviews objectAtIndex:0];
    originalBackground.hidden = NO;
}

@end
