//
//  YIFullScreenScroll.m
//  YIFullScreenScroll
//
//  Created by Yasuhiro Inami on 12/06/03.
//  Copyright (c) 2012 Yasuhiro Inami. All rights reserved.
//

#import "YIFullScreenScroll.h"
#import <objc/runtime.h>
#import "UIView+YIFullScreenScroll.h"

#define IS_PORTRAIT         UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)
#define STATUS_BAR_HEIGHT   (IS_PORTRAIT ? [UIApplication sharedApplication].statusBarFrame.size.height : [UIApplication sharedApplication].statusBarFrame.size.width)

#define MAX_SHIFT_PER_SCROLL    10

static char __fullScreenScrollContext;


@interface YIFullScreenScroll ()

@property (nonatomic) BOOL isShowingUIBars;
@property (nonatomic) BOOL isViewVisible;

@end


@implementation YIFullScreenScroll
{
    UINavigationBar*    _navigationBar;
    UIToolbar*          _toolbar;
    UITabBar*           _tabBar;
    
    UIImageView*        _customNavBarBackground;
    UIImageView*        _customToolbarBackground;
    
    UIEdgeInsets        _scrollIndicatorInsetsOnInit;
    
    BOOL _isObservingNavBar;
    BOOL _isObservingToolbar;
    
    BOOL _ignoresTranslucent;
}

#pragma mark -

#pragma mark Init/Dealloc

- (id)initWithViewController:(UIViewController*)viewController
                  scrollView:(UIScrollView*)scrollView
{
    return [self initWithViewController:viewController
                             scrollView:scrollView
                     ignoresTranslucent:YES];
}

- (id)initWithViewController:(UIViewController*)viewController
                  scrollView:(UIScrollView*)scrollView
          ignoresTranslucent:(BOOL)ignoresTranslucent
{
    self = [super init];
    if (self) {
        
        _viewController = viewController;
        _scrollView = scrollView;
        _ignoresTranslucent = ignoresTranslucent;
        
        _shouldShowUIBarsOnScrollUp = YES;
        _shouldHideNavigationBarOnScroll = YES;
        _shouldHideToolbarOnScroll = YES;
        _shouldHideTabBarOnScroll = YES;
        
        _scrollIndicatorInsetsOnInit = scrollView.scrollIndicatorInsets;
        
        [_scrollView addObserver:self forKeyPath:@"contentOffset" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&__fullScreenScrollContext];
        
        self.enabled = YES;
        
    }
    return self;
}

- (void)dealloc
{
    [self.scrollView removeObserver:self forKeyPath:@"contentOffset" context:&__fullScreenScrollContext];
    
    self.enabled = NO;
}

#pragma mark -

#pragma mark Accessors

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
        [self _setupUIBarBackgrounds];
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
}

- (void)viewWillDisappear:(BOOL)animated
{
    self.isViewVisible = NO;
    
    if (self.enabled) {
//        [self showUIBarsAnimated:NO]; // moved to viewWillAppear
        [self _teardownUIBarBackgrounds];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    self.isViewVisible = NO;
    
    if (self.enabled) {
        [self _layoutContainerViewExpanding:NO];
    }
}

- (void)showUIBarsAnimated:(BOOL)animated
{
    self.isShowingUIBars = YES;
    
    if (animated) {
        
        __weak typeof(self) weakSelf = self;
        
        [UIView animateWithDuration:0.1 animations:^{
            
            // pretend to scroll up by 50 pt which is longer than navBar/toolbar/tabBar height
            [weakSelf _layoutUIBarsWithDeltaY:-50];
            
        } completion:^(BOOL finished) {
            
            weakSelf.isShowingUIBars = NO;
            
        }];
    }
    else {
        [self _layoutUIBarsWithDeltaY:-50];
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
            if (!self.isViewVisible) return;
            
            CGPoint newPoint = [change[NSKeyValueChangeNewKey] CGPointValue];
            CGPoint oldPoint = [change[NSKeyValueChangeOldKey] CGPointValue];
            
            CGFloat deltaY = newPoint.y - oldPoint.y;
            
            [self _layoutUIBarsWithDeltaY:deltaY];
            
        }
        
    }
}

#pragma mark -

#pragma mark UIBars

- (UINavigationBar*)navigationBar
{
    if (!_navigationBar) {
        _navigationBar = _viewController.navigationController.navigationBar;
    }
    return _navigationBar;
}

- (UIToolbar*)toolbar
{
    if (!_toolbar) {
        _toolbar = _viewController.navigationController.toolbar;
    }
    return _toolbar;
}

- (UITabBar*)tabBar
{
    if (!_tabBar) {
        _tabBar = _viewController.tabBarController.tabBar;
    }
    return _tabBar;
}

- (BOOL)isNavigationBarExisting
{
    UINavigationBar* navBar = self.navigationBar;
    return navBar && navBar.superview && !navBar.hidden && !_viewController.navigationController.navigationBarHidden;
}

- (BOOL)isToolbarExisting
{
    UIToolbar* toolbar = self.toolbar;
    return toolbar && toolbar.superview && !toolbar.hidden && !_viewController.navigationController.toolbarHidden;
}

- (BOOL)isTabBarExisting
{
    UITabBar* tabBar = self.tabBar;
    
    // NOTE: tabBar.left == 0 is required when hidesBottomBarWhenPushed=YES
    return tabBar && tabBar.superview && !tabBar.hidden && (tabBar.left == 0);
}

#pragma mark -

#pragma mark Layout

- (void)_layoutUIBarsWithDeltaY:(CGFloat)deltaY
{
    if (!self.enabled) return;
    if (deltaY == 0.0) return;
    
    UIScrollView* scrollView = self.scrollView;
    
    if (!self.isShowingUIBars) {
        //
        // Don't let UI-bars appear when:
        // 1. scroll reaches to bottom
        // 2. shouldShowUIBarsOnScrollUp = NO & scrolling up (until offfset.y reaches top)
        //
        if (scrollView.contentOffset.y+scrollView.frame.size.height > scrollView.contentSize.height ||
            (!self.shouldShowUIBarsOnScrollUp && deltaY < 0 && scrollView.contentOffset.y > 0)) {
            
            deltaY = fabs(deltaY);
        }
        // always set negative when scrolling up too high
        else if (scrollView.contentOffset.y <= -scrollView.contentInset.top) {
            
            deltaY = -fabs(deltaY);
        }
        
        deltaY = MIN(deltaY, MAX_SHIFT_PER_SCROLL);
        
        // NOTE: don't limit deltaY in case of navBar being partially hidden & scrolled-up very fast
        if (scrollView.contentOffset.y > 0) {
            deltaY = MAX(deltaY, -MAX_SHIFT_PER_SCROLL);
        }
    }
    
    // navbar
    UINavigationBar* navBar = self.navigationBar;
    BOOL isNavigationBarExisting = self.isNavigationBarExisting;
    if (isNavigationBarExisting && _shouldHideNavigationBarOnScroll) {
        navBar.top = MIN(MAX(navBar.top-deltaY, STATUS_BAR_HEIGHT-navBar.height), STATUS_BAR_HEIGHT);
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
        toolbar.top = MIN(MAX(toolbar.top+deltaY, toolbarSuperviewHeight-toolbar.height), toolbarSuperviewHeight);
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
        tabBar.top = MIN(MAX(tabBar.top+deltaY, tabBarSuperviewHeight-tabBar.height), tabBarSuperviewHeight);
    }
    
    // scrollIndicatorInsets
    UIEdgeInsets insets = scrollView.scrollIndicatorInsets;
    if (isNavigationBarExisting && _shouldHideNavigationBarOnScroll) {
        insets.top = navBar.bottom-STATUS_BAR_HEIGHT;
    }
    insets.bottom = 0;
    if (isToolbarExisting && _shouldHideToolbarOnScroll) {
        insets.bottom += toolbarSuperviewHeight-toolbar.top;
    }
    if (isTabBarExisting && _shouldHideTabBarOnScroll) {
        insets.bottom += tabBarSuperviewHeight-tabBar.top;
    }
    scrollView.scrollIndicatorInsets = insets;
    
}

- (void)_layoutContainerViewExpanding:(BOOL)expanding
{
    // toolbar (iOS5 fix which doesn't re-layout when translucent is set)
    if (_shouldHideToolbarOnScroll && self.isToolbarExisting) {
        BOOL toolbarHidden = _viewController.navigationController.toolbarHidden;
        [_viewController.navigationController setToolbarHidden:!toolbarHidden];
        [_viewController.navigationController setToolbarHidden:toolbarHidden];
    }
    
    // tabBar
    if (_shouldHideTabBarOnScroll && self.isTabBarExisting) {
        
        UIView* tabBarTransitionView = [_viewController.tabBarController.view.subviews objectAtIndex:0];
        
        if (expanding) {
            tabBarTransitionView.frame = _viewController.tabBarController.view.bounds;
        }
        else {
            UITabBar* tabBar = self.tabBar;
            
            CGRect frame = _viewController.tabBarController.view.bounds;
            frame.size.height -= tabBar.height;
            tabBarTransitionView.frame = frame;
            
            // scrollIndicatorInsets will be modified when tabBarTransitionView shrinks, so reset it here.
            _scrollView.scrollIndicatorInsets = _scrollIndicatorInsetsOnInit;
        }
    }
    
}

#pragma mark -

#pragma mark Custom Background

- (void)_setupUIBarBackgrounds
{
    if (_viewController.navigationController) {
        
        UINavigationBar* navBar = self.navigationBar;
        UIToolbar* toolbar = self.toolbar;
        
        // navBar
        if (_shouldHideNavigationBarOnScroll) {
            
            // hide original background & add opaque custom one
            if (_ignoresTranslucent) {
                [self _addCustomBackgroundOnUIBar:navBar];
                
                if (!_isObservingNavBar) {
                    [navBar addObserver:self forKeyPath:@"tintColor" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&__fullScreenScrollContext];
                    _isObservingNavBar = YES;
                }
            }
            navBar.translucent = YES;
        }
        else {
            navBar.translucent = NO;
        }
        
        // toolbar
        if (_shouldHideToolbarOnScroll) {
            
            // hide original background & add opaque custom one
            if (_ignoresTranslucent) {
                [self _addCustomBackgroundOnUIBar:toolbar];
                
                if (!_isObservingToolbar) {
                    [toolbar addObserver:self forKeyPath:@"tintColor" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:&__fullScreenScrollContext];
                    _isObservingToolbar = YES;
                }
                
            }
            toolbar.translucent = YES;
        }
        else {
            toolbar.translucent = NO;
        }
    }
}

- (void)_teardownUIBarBackgrounds
{
    if (_ignoresTranslucent) {
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
    
    self.navigationBar.translucent = NO;
    self.toolbar.translucent = NO;
    
    _navigationBar = nil;
    _toolbar = nil;
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

- (void)_addCustomBackgroundOnUIBar:(UIView*)bar
{
    if (!bar) return;
    
    BOOL isUIBarHidden = NO;
    
    // temporarilly set translucent=NO to copy custom backgroundImage
    if (bar == self.navigationBar) {
        [_customNavBarBackground removeFromSuperview];
        self.navigationBar.translucent = NO;
        
        // temporarilly show navigationBar to copy backgroundImage safely
        isUIBarHidden = _viewController.navigationController.navigationBarHidden;
        if (isUIBarHidden) {
            [_viewController.navigationController setNavigationBarHidden:NO];
        }
    }
    else if (bar == self.toolbar) {
        [_customToolbarBackground removeFromSuperview];
        self.toolbar.translucent = NO;
        
        // temporarilly show toolbar to copy backgroundImage safely
        isUIBarHidden = _viewController.navigationController.toolbarHidden;
        if (isUIBarHidden) {
            [_viewController.navigationController setToolbarHidden:NO];
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
        self.navigationBar.translucent = YES;
        _customNavBarBackground = customBarImageView;
        
        // hide navigationBar if needed
        if (isUIBarHidden) {
            [_viewController.navigationController setNavigationBarHidden:YES];
        }
    }
    else if (bar == self.toolbar) {
        self.toolbar.translucent = YES;
        _customToolbarBackground = customBarImageView;
        
        // hide toolbar if needed
        if (isUIBarHidden) {
            [_viewController.navigationController setToolbarHidden:YES];
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
