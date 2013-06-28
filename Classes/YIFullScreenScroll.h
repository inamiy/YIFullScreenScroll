//
//  YIFullScreenScroll.h
//  YIFullScreenScroll
//
//  Created by Yasuhiro Inami on 12/06/03.
//  Copyright (c) 2012 Yasuhiro Inami. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIViewController+YIFullScreenScroll.h"

@protocol YIFullScreenScrollDelegate;

//
// NOTE:
// YIFullScreenScroll forces viewController.navigationController's navigationBar/toolbar
// to set translucent=YES (to set navigationController's content size wider for convenience),
// and sets custom background imageView to make it opaque again.
//
@interface YIFullScreenScroll : NSObject

@property (nonatomic, weak) id <YIFullScreenScrollDelegate> delegate;

@property (nonatomic, weak) UIViewController* viewController;
@property (nonatomic, strong) UIScrollView* scrollView;

@property (nonatomic) BOOL enabled; // default = YES

@property (nonatomic) BOOL layoutingUIBarsEnabled; // can pause layouting UI-bars, default = YES

@property (nonatomic) BOOL shouldShowUIBarsOnScrollUp;      // default = YES

@property (nonatomic) BOOL shouldHideNavigationBarOnScroll; // default = YES
@property (nonatomic) BOOL shouldHideToolbarOnScroll;       // default = YES
@property (nonatomic) BOOL shouldHideTabBarOnScroll;        // default = YES

@property (nonatomic) BOOL shouldHideUIBarsGradually;       // default = YES

// if YES, UI-bars can also be hidden via UIWebView's JavaScript calling window.scrollTo(0,1))
@property (nonatomic) BOOL shouldHideUIBarsWhenNotDragging;             // default = NO

@property (nonatomic) BOOL shouldHideUIBarsWhenContentHeightIsTooShort; // default = NO

@property (nonatomic) CGFloat additionalOffsetYToStartHiding;   // default = 0.0
@property (nonatomic) CGFloat additionalOffsetYToStartShowing;  // default = 0.0

- (id)initWithViewController:(UIViewController*)viewController
                  scrollView:(UIScrollView*)scrollView;

- (void)showUIBarsAnimated:(BOOL)animated;
- (void)showUIBarsAnimated:(BOOL)animated completion:(void (^)(BOOL finished))completion;

// used in UIViewController+YIFullScreenScroll
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration;

@end


@protocol YIFullScreenScrollDelegate <NSObject>

@optional

//
// Use this method to layout your custom views after
// default UI-bars (navigationBar/toolbar/tabBar) are set.
//
// NOTE:
// This method is different from UIScrollViewDelegate's '-scrollViewDidScroll:'
// which will be called on next run-loop after contentOffset is observed & layout is triggered.
// This means that default UI-bars & your custom views may not layout synchronously
// if you use '-scrollViewDidScroll:'.
//
- (void)fullScreenScrollDidLayoutUIBars:(YIFullScreenScroll*)fullScreenScroll;

@end
