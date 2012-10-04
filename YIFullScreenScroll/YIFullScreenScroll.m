//
//  YIFullScreenScroll.m
//  YIFullScreenScroll
//
//  Created by Yasuhiro Inami on 12/06/03.
//  Copyright (c) 2012 Yasuhiro Inami. All rights reserved.
//

#import "YIFullScreenScroll.h"
#import "UIView+YIFullScreenScroll.h"

#define IS_PORTRAIT         UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)
#define STATUS_BAR_HEIGHT   (IS_PORTRAIT ? [UIApplication sharedApplication].statusBarFrame.size.height : [UIApplication sharedApplication].statusBarFrame.size.width)

#define MAX_SHIFT_PER_SCROLL    10


@implementation YIFullScreenScroll
{
    BOOL _willScrollToBottom;
    
    UINavigationBar*    _navigationBar;
    UIToolbar*          _toolbar;
    UITabBar*           _tabBar;
    
    UIImageView*        _opaqueNavBarBackground;
    UIImageView*        _opaqueToolbarBackground;
    
    BOOL _isObservingNavBar;
    BOOL _isObservingToolbar;
    
    BOOL _isNavBarTranslucentOnInit;
    BOOL _isToolbarTranslucentOnInit;
    
    BOOL _hasOpaqueNavBarBackgroundOnInit;
    BOOL _hasOpaqueToolbarBackgroundOnInit;
    
    BOOL _ignoresTranslucent;
}

@synthesize viewController = _viewController;
@synthesize enabled = _enabled;
@synthesize shouldShowUIBarsOnScrollUp = _shouldShowUIBarsOnScrollUp;

- (id)initWithViewController:(UIViewController*)viewController
{
    return [self initWithViewController:viewController ignoreTranslucent:YES];
}

- (id)initWithViewController:(UIViewController*)viewController ignoreTranslucent:(BOOL)ignoreTranslucent
{
    self = [super init];
    if (self) {
        
        _viewController = viewController;
        _ignoresTranslucent = ignoreTranslucent;
        
        if (![self _hasOpaqueBackgroundOnUIBar:self.navigationBar]) {
            _hasOpaqueNavBarBackgroundOnInit = NO;
            _isNavBarTranslucentOnInit = self.navigationBar.translucent;
        }
        else {
            _hasOpaqueNavBarBackgroundOnInit = YES;
        }
        
        if (![self _hasOpaqueBackgroundOnUIBar:self.toolbar]) {
            _hasOpaqueToolbarBackgroundOnInit = NO;
            _isToolbarTranslucentOnInit = self.toolbar.translucent;
        }
        else {
            _hasOpaqueToolbarBackgroundOnInit = YES;
        }
        
        self.enabled = YES;
        self.shouldShowUIBarsOnScrollUp = YES;
        
    }
    return self;
}

- (void)_setupUIBarBackgrounds
{
    if (_viewController.navigationController) {
        
        UINavigationBar* navBar = self.navigationBar;
        if (navBar) {
            
            // hide original background & add non-translucent one
            if (_ignoresTranslucent) {
                [self _hideOriginalAndAddOpaqueBackgroundOnUIBar:navBar];
                
                if (!_isObservingNavBar) {
                    [navBar addObserver:self forKeyPath:@"tintColor" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
                    _isObservingNavBar = YES;
                }
                
            }
            
            navBar.translucent = YES;
        }
        
        UIToolbar* toolbar = self.toolbar;
        if (toolbar) {
            
            // hide original background & add non-translucent one
            if (_ignoresTranslucent) {
                [self _hideOriginalAndAddOpaqueBackgroundOnUIBar:toolbar];
                
                if (!_isObservingToolbar) {
                    [toolbar addObserver:self forKeyPath:@"tintColor" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:NULL];
                    _isObservingToolbar = YES;
                }
                
            }
            
            toolbar.translucent = YES;
        }
        
    }
}

- (void)_teardownUIBarBackgrounds
{
    if (_ignoresTranslucent) {
        if (!_hasOpaqueNavBarBackgroundOnInit) {
            [self _showOriginalAndRemoveOpaqueBackgroundOnUIBar:self.navigationBar];
        }
        if (!_hasOpaqueToolbarBackgroundOnInit) {
            [self _showOriginalAndRemoveOpaqueBackgroundOnUIBar:self.toolbar];
        }
        
        if (_isObservingNavBar) {
            [self.navigationBar removeObserver:self forKeyPath:@"tintColor" context:NULL];
            _isObservingNavBar= NO;
        }
        if (_isObservingToolbar) {
            [self.toolbar removeObserver:self forKeyPath:@"tintColor" context:NULL];
            _isObservingToolbar = NO;
        }
    }

    // set UI-bars back to initial state if all of fullScreenScroll is deallocated
    if (!_hasOpaqueNavBarBackgroundOnInit) {
        self.navigationBar.translucent = _isNavBarTranslucentOnInit;
    }
    if (!_hasOpaqueToolbarBackgroundOnInit) {
        self.toolbar.translucent = _isToolbarTranslucentOnInit;
    }
    
    _navigationBar = nil;
    _toolbar = nil;
}

- (BOOL)_hasOpaqueBackgroundOnUIBar:(UIView*)bar
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

- (void)_hideOriginalAndAddOpaqueBackgroundOnUIBar:(UIView*)bar
{
    BOOL isUIBarHidden = NO;
    
    // temporally set translucent=NO to copy opaque backgroundImage
    if (bar == self.navigationBar) {
        [_opaqueNavBarBackground removeFromSuperview];
        self.navigationBar.translucent = NO;
        
        // temporally show navigationBar to copy backgroundImage safely
        isUIBarHidden = _viewController.navigationController.navigationBarHidden;
        if (isUIBarHidden) {
            [_viewController.navigationController setNavigationBarHidden:NO];
        }
    }
    else if (bar == self.toolbar) {
        [_opaqueToolbarBackground removeFromSuperview];
        self.toolbar.translucent = NO;
        
        // temporally show toolbar to copy backgroundImage safely
        isUIBarHidden = _viewController.navigationController.toolbarHidden;
        if (isUIBarHidden) {
            [_viewController.navigationController setToolbarHidden:NO];
        }
    }
    else {
        return;
    }
    
    UIImageView* originalBackground = nil;
    UIImageView* opaqueBarImageView = nil;
    
    // use existing opaque background
    if ([self _hasOpaqueBackgroundOnUIBar:bar]) {
        originalBackground = [bar.subviews objectAtIndex:1];
        opaqueBarImageView = [bar.subviews objectAtIndex:0];
        opaqueBarImageView.image = [originalBackground.image copy];
    }
    // create opaque background
    else {
        originalBackground = [bar.subviews objectAtIndex:0];
        opaqueBarImageView = [[UIImageView alloc] initWithImage:[originalBackground.image copy]];
        [bar insertSubview:opaqueBarImageView atIndex:0];
    }
    originalBackground.hidden = YES;
    opaqueBarImageView.opaque = YES;
    opaqueBarImageView.frame = originalBackground.frame;
    opaqueBarImageView.autoresizingMask = originalBackground.autoresizingMask;
    
    if (bar == self.navigationBar) {
        self.navigationBar.translucent = YES;
        _opaqueNavBarBackground = opaqueBarImageView;
        
        // hide navigationBar if needed
        if (isUIBarHidden) {
            [_viewController.navigationController setNavigationBarHidden:YES];
        }
    }
    else if (bar == self.toolbar) {
        self.toolbar.translucent = YES;
        _opaqueToolbarBackground = opaqueBarImageView;
        
        // hide toolbar if needed
        if (isUIBarHidden) {
            [_viewController.navigationController setToolbarHidden:YES];
        }
    }
}

- (void)_showOriginalAndRemoveOpaqueBackgroundOnUIBar:(UIView*)bar
{
    if (bar == self.navigationBar) {
        [_opaqueNavBarBackground removeFromSuperview];
    }
    else if (bar == self.toolbar) {
        [_opaqueToolbarBackground removeFromSuperview];
    }
    else {
        return;
    }
    
    UIImageView* originalBackground = [bar.subviews objectAtIndex:0];
    originalBackground.hidden = NO;
}

- (void)dealloc
{
    [self _teardownUIBarBackgrounds];
    _tabBar = nil;
}

#pragma mark -

#pragma mark Accessors

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
    
    if (enabled) {
        [self _setupUIBarBackgrounds];
    }
    else {
        [self _teardownUIBarBackgrounds];
    }
    
}

#pragma mark -

#pragma mark Public

- (void)layoutTabBarController
{
    if (_viewController.tabBarController) {
        UIView* tabBarTransitionView = [_viewController.tabBarController.view.subviews objectAtIndex:0];
        tabBarTransitionView.frame = _viewController.tabBarController.view.bounds;
    }
}

- (void)showUIBarsWithScrollView:(UIScrollView*)scrollView animated:(BOOL)animated
{
    [UIView animateWithDuration:(animated ? 0.1 : 0) animations:^{
        [self _layoutWithScrollView:scrollView deltaY:-50];
    }];
}

#pragma mark -

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (!self.enabled) return;
    
    if ([keyPath isEqualToString:@"tintColor"]) {
        [self _hideOriginalAndAddOpaqueBackgroundOnUIBar:object];
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

#pragma mark -

#pragma mark Scroll & Layout

- (void)_layoutWithScrollView:(UIScrollView*)scrollView deltaY:(CGFloat)deltaY
{
    if (!self.enabled) return;
    
    // navbar
    UINavigationBar* navBar = self.navigationBar;
    BOOL isNavBarExisting = navBar && navBar.superview && !navBar.hidden;
    if (isNavBarExisting) {
        navBar.top = MIN(MAX(navBar.top-deltaY, STATUS_BAR_HEIGHT-navBar.height), STATUS_BAR_HEIGHT);
    }
    
    // toolbar
    UIToolbar* toolbar = self.toolbar;
    BOOL isToolbarExisting = toolbar && toolbar.superview && !toolbar.hidden;
    CGFloat toolbarSuperviewHeight = 0;
    if (isToolbarExisting) {
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
    BOOL isTabBarExisting = tabBar && tabBar.superview && !tabBar.hidden && (tabBar.left == 0);
    CGFloat tabBarSuperviewHeight = 0;
    if (isTabBarExisting) {
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
    if (isNavBarExisting) {
        insets.top = navBar.bottom-STATUS_BAR_HEIGHT;
    }
    insets.bottom = 0;
    if (isToolbarExisting) {
        insets.bottom += toolbarSuperviewHeight-toolbar.top;
    }
    if (isTabBarExisting) {
        insets.bottom += tabBarSuperviewHeight-tabBar.top;
    }
    scrollView.scrollIndicatorInsets = insets;
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    _prevContentOffsetY = scrollView.contentOffset.y;
    _willScrollToBottom = NO;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.dragging || scrollView.decelerating || _isScrollingTop) {
        CGFloat deltaY = scrollView.contentOffset.y-_prevContentOffsetY;
        _prevContentOffsetY = MAX(scrollView.contentOffset.y, -scrollView.contentInset.top);
        
        //
        // Don't let UI-bars appear when:
        // 1. scroll reaches to bottom
        // 2. shouldShowUIBarsOnScrollUp = NO & scrolling up (ignore status-bar-tap)
        //
        if (_willScrollToBottom || (!self.shouldShowUIBarsOnScrollUp && deltaY < 0 && scrollView.contentOffset.y > 0 && !_isScrollingTop)) {
            deltaY = fabs(deltaY);
        }
        
        if (deltaY > MAX_SHIFT_PER_SCROLL) {
            deltaY = MAX_SHIFT_PER_SCROLL;
        }
        // NOTE: scrollView.contentOffset.y > 0 is preferred when navBar is partially hidden & scrolled-up very fast
        else if (deltaY < -MAX_SHIFT_PER_SCROLL && scrollView.contentOffset.y > 0) {
            deltaY = -MAX_SHIFT_PER_SCROLL;
        }
        
        [self _layoutWithScrollView:scrollView deltaY:deltaY];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    _willScrollToBottom = (velocity.y > 0 && (*targetContentOffset).y+scrollView.bounds.size.height >= scrollView.contentSize.height+scrollView.contentInset.bottom);
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    _prevContentOffsetY = scrollView.contentOffset.y;
    _isScrollingTop = YES;
    _willScrollToBottom = NO;
    return YES;
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView
{
    _isScrollingTop = NO;
}

@end
