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
        self.enabled = YES;
        self.shouldShowUIBarsOnScrollUp = YES;
        
        if (viewController.navigationController) {
            
            if (viewController.navigationController.navigationBar) {
                
                // hide original background & add non-translucent one
                if (ignoreTranslucent) {
                    UIImageView* navBarBackground = [viewController.navigationController.navigationBar.subviews objectAtIndex:0];
                    navBarBackground.hidden = YES;
                    
                    UIImage* navBarImage = [navBarBackground.image copy];
                    UIImageView* navBarImageView = [[UIImageView alloc] initWithImage:navBarImage];
                    navBarImageView.opaque = YES;
                    navBarImageView.frame = navBarBackground.frame;
                    navBarImageView.autoresizingMask = navBarBackground.autoresizingMask;
                    [viewController.navigationController.navigationBar insertSubview:navBarImageView atIndex:0];
                }
                
                viewController.navigationController.navigationBar.translucent = YES;
            }
            
            if (viewController.navigationController.toolbar) {
                
                // hide original background & add non-translucent one
                if (ignoreTranslucent) {
                    UIImageView* toolbarBackground = [viewController.navigationController.toolbar.subviews objectAtIndex:0];
                    toolbarBackground.hidden = YES;
                    
                    UIImage* toolbarImage = [toolbarBackground.image copy];
                    UIImageView* toolbarImageView = [[UIImageView alloc] initWithImage:toolbarImage];
                    toolbarImageView.opaque = YES;
                    toolbarImageView.frame = toolbarBackground.frame;
                    toolbarImageView.autoresizingMask = toolbarBackground.autoresizingMask;
                    [viewController.navigationController.toolbar insertSubview:toolbarImageView atIndex:0];
                }
                
                viewController.navigationController.toolbar.translucent = YES;
            }
            
        }
        
        _viewController = viewController;
    }
    return self;
}

- (void)_layoutWithScrollView:(UIScrollView*)scrollView deltaY:(CGFloat)deltaY
{
    if (!self.enabled) return;
    
    // navbar
    UINavigationBar* navBar = _viewController.navigationController.navigationBar;
    BOOL isNavBarExisting = navBar && navBar.superview && !navBar.hidden;
    if (isNavBarExisting) {
        navBar.top = MIN(MAX(navBar.top-deltaY, STATUS_BAR_HEIGHT-navBar.height), STATUS_BAR_HEIGHT);
    }
    
    // toolbar
    UIToolbar* toolbar = _viewController.navigationController.toolbar;
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
    UITabBar* tabBar = _viewController.tabBarController.tabBar;
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

#pragma mark -

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
