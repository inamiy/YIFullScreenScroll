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
#import "JRSwizzle.h"

#define IS_PORTRAIT             UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)
#define IS_IOS_AT_LEAST(ver)    ([[[UIDevice currentDevice] systemVersion] compare:ver] != NSOrderedAscending)

#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
#   define IS_FLAT_DESIGN          IS_IOS_AT_LEAST(@"7.0")
#else
#   define IS_FLAT_DESIGN          NO
#endif

#define IS_PORTRAIT             UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)
#define STATUS_BAR_HEIGHT       (IS_PORTRAIT ? [UIApplication sharedApplication].statusBarFrame.size.height : [UIApplication sharedApplication].statusBarFrame.size.width)

#define MAX_SHIFT_PER_SCROLL    10  // used when _shouldHideUIBarsGradually=YES

static char __fullScreenScrollContext;

static char __isFullScreenScrollViewKey;


#pragma mark -

#pragma mark Private Categories


@implementation UIScrollView (YIFullScreenScroll)

- (BOOL)isFullScreenScrollView
{
    return [objc_getAssociatedObject(self, &__isFullScreenScrollViewKey) boolValue];
}

- (void)setIsFullScreenScrollView:(BOOL)flag
{
    objc_setAssociatedObject(self, &__isFullScreenScrollViewKey, @(flag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end


@implementation UISearchBar (YIFullScreenScroll)

+ (void)load
{
    [UISearchBar jr_swizzleMethod:@selector(layoutSubviews)
                       withMethod:@selector(YIFullScreenScroll_layoutSubviews)
                            error:NULL];
}

- (void)YIFullScreenScroll_layoutSubviews
{
    [self YIFullScreenScroll_layoutSubviews];
    
    if (!IS_FLAT_DESIGN) return;
    
    if ([self.superview isKindOfClass:[UIScrollView class]]) {
        UIScrollView* scrollView = (id)self.superview;
        if (scrollView.isFullScreenScrollView) {
            [self.subviews[0] setClipsToBounds:NO];     // disable wrapper's clipsToBounds
        }
    }
}

@end


#pragma mark -


@interface YIFullScreenScroll ()

@property (nonatomic) BOOL areUIBarsAnimating;
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
    
    BOOL _areUIBarBackgroundsReady;
    
    BOOL _isObservingNavBar;
    BOOL _isObservingToolbar;
}

#pragma mark -

#pragma mark Init/Dealloc

- (id)initWithViewController:(UIViewController*)viewController
                  scrollView:(UIScrollView*)scrollView
{
    return [self initWithViewController:viewController scrollView:scrollView style:YIFullScreenScrollStyleDefault];
}

- (id)initWithViewController:(UIViewController*)viewController
                  scrollView:(UIScrollView*)scrollView
                       style:(YIFullScreenScrollStyle)style
{
    self = [super init];
    if (self) {
        
        _viewController = viewController;
        
        _shouldShowUIBarsOnScrollUp = YES;
        
        _shouldHideNavigationBarOnScroll = YES;
        _shouldHideToolbarOnScroll = YES;
        _shouldHideTabBarOnScroll = YES;
        
        _shouldHideUIBarsGradually = YES;
        _shouldHideUIBarsWhenNotDragging = NO;
        _shouldHideUIBarsWhenContentHeightIsTooShort = NO;
        
        _additionalOffsetYToStartHiding = 0.0;
        _additionalOffsetYToStartShowing = 0.0;
        
        _showHideAnimationDuration = 0.1;
        
        _enabled = YES; // don't call self.enabled = YES
        
        _layoutingUIBarsEnabled = YES;
        
        // call setter
        _style = -1;
        self.style = style;
        
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
            _scrollView.isFullScreenScrollView = NO;
            
            [_scrollView removeObserver:self forKeyPath:@"contentOffset" context:&__fullScreenScrollContext];
            
            [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
        }
        
        _scrollView = scrollView;
        
        if (_scrollView) {
            _scrollView.isFullScreenScrollView = YES;
            
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

- (void)setStyle:(YIFullScreenScrollStyle)style
{
    if (style != _style) {
        _style = style;
        
        // auto-adjust
        if (IS_FLAT_DESIGN && style == YIFullScreenScrollStyleFacebook) {
            _additionalOffsetYToStartShowing = -STATUS_BAR_HEIGHT;
        }
        else {
            _additionalOffsetYToStartShowing = 0;
        }
    }
}

#pragma mark -

#pragma mark Public

- (void)showUIBarsAnimated:(BOOL)animated
{
    [self showUIBarsAnimated:animated completion:NULL];
}

- (void)showUIBarsAnimated:(BOOL)animated completion:(void (^)(BOOL finished))completion
{
    if (!self.enabled) return;
    
    self.areUIBarsAnimating = YES;
    
    if (animated) {
        
        __weak typeof(self) weakSelf = self;
        
        [UIView animateWithDuration:self.showHideAnimationDuration animations:^{
            
            // pretend to scroll up by 50 pt which is longer than navBar/toolbar/tabBar height
            [weakSelf _layoutUIBarsWithDeltaY:-50-self.additionalNavBarShiftForIOS7StatusBar];
            
        } completion:^(BOOL finished) {
            
            weakSelf.areUIBarsAnimating = NO;
            
            if (completion) {
                completion(finished);
            }
            
        }];
    }
    else {
        [self _layoutUIBarsWithDeltaY:-50-self.additionalNavBarShiftForIOS7StatusBar];
        self.areUIBarsAnimating = NO;
    }
}

- (void)hideUIBarsAnimated:(BOOL)animated
{
    [self hideUIBarsAnimated:animated completion:NULL];
}

- (void)hideUIBarsAnimated:(BOOL)animated completion:(void (^)(BOOL finished))completion
{
    if (!self.enabled) return;
    
    self.areUIBarsAnimating = YES;
    
    if (animated) {
        
        __weak typeof(self) weakSelf = self;
        
        [UIView animateWithDuration:self.showHideAnimationDuration animations:^{
            
            // pretend to scroll up by 50 pt which is longer than navBar/toolbar/tabBar height
            [weakSelf _layoutUIBarsWithDeltaY:50+self.additionalNavBarShiftForIOS7StatusBar];
            
        } completion:^(BOOL finished) {
            
            weakSelf.areUIBarsAnimating = NO;
            
            if (completion) {
                completion(finished);
            }
            
        }];
    }
    else {
        [self _layoutUIBarsWithDeltaY:50+self.additionalNavBarShiftForIOS7StatusBar];
        self.areUIBarsAnimating = NO;
    }
}

- (void)adjustScrollPositionWhenSearchDisplayControllerBecomeActive
{
    if (IS_FLAT_DESIGN) {
        [self.scrollView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
    }
}

#pragma mark -

#pragma mark Private

- (CGFloat)additionalNavBarShiftForIOS7StatusBar
{
    // style=Facebook keeps statusBar-background visible, so pretend there's no additional navBar-shift
    if (IS_FLAT_DESIGN && _style == YIFullScreenScrollStyleFacebook) return 0;
    
    return IS_FLAT_DESIGN ? STATUS_BAR_HEIGHT : 0;
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
    
    if (!self.areUIBarsAnimating) {
        
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
        
        // return if user hasn't dragged but trying to hide UI-bars (e.g. orientation change)
        if (deltaY > 0 && !self.scrollView.isDragging && !self.shouldHideUIBarsWhenNotDragging) return;
    }
    
    if (deltaY == 0.0) return;
    
    // navbar
    UINavigationBar* navBar = self.navigationBar;
    BOOL isNavigationBarExisting = self.isNavigationBarExisting;
    if (isNavigationBarExisting && _shouldHideNavigationBarOnScroll) {
        
        if (canLayoutUIBars) {
            
            navBar.top = MIN(MAX(navBar.top-deltaY, _defaultNavBarTop-navBar.height-self.additionalNavBarShiftForIOS7StatusBar), _defaultNavBarTop);
            
            //
            // fade-out left/right/title navBar-subviews for style=Facebook
            // (NOTE: don't fade background or _UINavigationBarBackIndicatorView)
            //
            if (IS_FLAT_DESIGN && _style == YIFullScreenScrollStyleFacebook) {
                
                //
                // NOTE:
                // _UINavigationBarBackIndicatorView has alpha=0 for navigationController.rootViewController,
                // so use hiddenAlpha (> 0) to ignore indicatorView from fade-in/out.
                //
                const CGFloat hiddenAlpha = 0.001;
                
                CGFloat alpha = MAX(1-(_defaultNavBarTop-navBar.top)/(navBar.height-5), hiddenAlpha);  // -5 for faster fadeout
                
                // for non-customized title
                UIColor *titleTextColor = navBar.titleTextAttributes[NSForegroundColorAttributeName] ?: [UIColor blackColor];
                titleTextColor = [titleTextColor colorWithAlphaComponent:alpha];
                NSMutableDictionary *titleTextAttributes = [navBar.titleTextAttributes mutableCopy];
                [titleTextAttributes setObject:titleTextColor forKey:NSForegroundColorAttributeName];
                [navBar setTitleTextAttributes:titleTextAttributes];
                
                // for customized title
                if (![_viewController.navigationItem.titleView conformsToProtocol:@protocol(YIFullScreenScrollNoFading)]) {
                    _viewController.navigationItem.titleView.alpha = alpha;
                }
                
                // for left/right barButtonItems (both customized & non-customized)
                for (UIButton* navSubview in _viewController.navigationController.navigationBar.subviews) {
                    
                    if ([navSubview conformsToProtocol:@protocol(YIFullScreenScrollNoFading)]||
                        navSubview == [self _backgroundOnUIBar:navBar] ||
                        navSubview.hidden ||
                        navSubview.alpha <= 0) {
                        
                        continue;
                    }
                    
                    navSubview.alpha = alpha;
                }
            }
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
    if (isTabBarExisting) {
        if ([tabBar.superview.superview isKindOfClass:[UIWindow class]]) {
            tabBarSuperviewHeight = IS_PORTRAIT ? tabBar.superview.height : tabBar.superview.width;
        }
        else {
            tabBarSuperviewHeight = tabBar.superview.height;
        }
        
        if (canLayoutUIBars && _shouldHideTabBarOnScroll) {
            tabBar.top = MIN(MAX(tabBar.top+deltaY, tabBarSuperviewHeight-tabBar.height), tabBarSuperviewHeight);
        }
    }
    
    if (self.enabled && self.isViewVisible) {
        
        // scrollIndicatorInsets
        UIEdgeInsets insets = scrollView.scrollIndicatorInsets;
        if (isNavigationBarExisting && _shouldHideNavigationBarOnScroll) {
            insets.top = navBar.bottom-_defaultNavBarTop+self.additionalNavBarShiftForIOS7StatusBar;
            
            if (IS_FLAT_DESIGN && _style == YIFullScreenScrollStyleFacebook) {
                insets.top += STATUS_BAR_HEIGHT;
            }
        }
        insets.bottom = 0;
        if (isToolbarExisting && _shouldHideToolbarOnScroll) {
            insets.bottom += toolbarSuperviewHeight-toolbar.top;
        }
        if (isTabBarExisting) {
            // NOTE: don't adjust scrollIndicatorInsets.bottom for iOS6 + not hiding
            if (IS_FLAT_DESIGN || _shouldHideTabBarOnScroll) {
                insets.bottom += tabBarSuperviewHeight-tabBar.top;
            }
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
    if (IS_FLAT_DESIGN) return;
    
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

- (UIView*)_backgroundOnUIBar:(UIView*)bar
{
    if (bar == self.navigationBar) {
        return _customNavBarBackground ?: bar.subviews[0];
    }
    else if (bar == self.toolbar) {
        return _customToolbarBackground ?: bar.subviews[0];
    }
    
    return nil;
}

- (void)_setupUIBarBackgrounds
{
    if (_areUIBarBackgroundsReady) return;
    
    if (self.navigationController) {
        
        UINavigationBar* navBar = self.navigationBar;
        UIToolbar* toolbar = self.toolbar;
        
        // navBar
        if (_shouldHideNavigationBarOnScroll) {
            
            // hide original background & add opaque custom one
            [self _addCustomBackgroundOnUIBar:navBar];
            
            if (!_isObservingNavBar) {
                [navBar addObserver:self forKeyPath:@"tintColor" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&__fullScreenScrollContext];
                _isObservingNavBar = YES;
            }
            navBar.translucent = YES;
        }
        else {
            navBar.translucent = NO;
        }
        
        // toolbar
        if (_shouldHideToolbarOnScroll) {
            
            // hide original background & add opaque custom one
            [self _addCustomBackgroundOnUIBar:toolbar];
            
            if (!_isObservingToolbar) {
                [toolbar addObserver:self forKeyPath:@"tintColor" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&__fullScreenScrollContext];
                _isObservingToolbar = YES;
            }
            toolbar.translucent = YES;
        }
        else {
            toolbar.translucent = NO;
        }
    }
    
    _areUIBarBackgroundsReady = YES;
}

- (void)_teardownUIBarBackgrounds
{
    if (!_areUIBarBackgroundsReady) return;
    
    // NOTE: don't set translucent=NO for iOS7 default flat-design, or bars will flash while transitioning
    if (!IS_FLAT_DESIGN || _customNavBarBackground) {
        self.navigationBar.translucent = NO;
    }
    if (!IS_FLAT_DESIGN || _customToolbarBackground) {
        self.toolbar.translucent = NO;
    }
    
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
    
    _areUIBarBackgroundsReady = NO;
}

// removes old & add new custom background for UINavigationBar/UIToolbar
- (void)_addCustomBackgroundOnUIBar:(UIView*)bar
{
    if (!bar) return;
    if (bar.subviews.count == 0) return;
    
    BOOL isUIBarHidden = NO;
    
    // temporarily set translucent=NO to copy custom backgroundImage
    if (bar == self.navigationBar) {
        [_customNavBarBackground removeFromSuperview];
        if (!IS_FLAT_DESIGN || _customNavBarBackground) {
            self.navigationBar.translucent = NO;
        }
        
        // temporarily show navigationBar to copy backgroundImage safely
        isUIBarHidden = self.navigationController.navigationBarHidden;
        if (isUIBarHidden) {
            self.navigationBar.hidden = NO;
        }
    }
    else if (bar == self.toolbar) {
        [_customToolbarBackground removeFromSuperview];
        if (!IS_FLAT_DESIGN || _customToolbarBackground) {
            self.toolbar.translucent = NO;
        }
        
        // temporarily show toolbar to copy backgroundImage safely
        isUIBarHidden = self.navigationController.toolbarHidden;
        if (isUIBarHidden) {
            self.toolbar.hidden = NO;
        }
    }
    
    // create custom background
    UIImageView* originalBackground = [bar.subviews objectAtIndex:0];
    UIImageView* customBarImageView = nil;
    
    // don't create customBarImageView for iOS7 default flat-design
    if (!IS_FLAT_DESIGN || originalBackground.image) {
        customBarImageView = [[UIImageView alloc] initWithImage:[originalBackground.image copy]];
        [bar insertSubview:customBarImageView atIndex:0];
        
        originalBackground.hidden = YES;
        customBarImageView.opaque = YES;
        customBarImageView.frame = originalBackground.frame;
        
        // NOTE: auto-resize when tintColored & rotated
        customBarImageView.autoresizingMask = originalBackground.autoresizingMask | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    
    if (bar == self.navigationBar) {
        if (!IS_FLAT_DESIGN || customBarImageView) {
            self.navigationBar.translucent = YES;
        }
        _customNavBarBackground = customBarImageView;
        
        // hide navigationBar if needed
        if (isUIBarHidden) {
            self.navigationBar.hidden = YES;
        }
    }
    else if (bar == self.toolbar) {
        if (!IS_FLAT_DESIGN || customBarImageView) {
            self.toolbar.translucent = YES;
        }
        _customToolbarBackground = customBarImageView;
        
        // hide toolbar if needed
        if (isUIBarHidden) {
            self.toolbar.hidden = YES;
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
    
    if (bar.subviews.count == 0) return;
    
    UIImageView* originalBackground = [bar.subviews objectAtIndex:0];
    originalBackground.hidden = NO;
}

@end


@implementation YIFullScreenScroll (ViewLifecycle)

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

@end
