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
@property (nonatomic, weak) UIScrollView* scrollView;

@property (nonatomic) BOOL enabled; // default = YES

@property (nonatomic) BOOL shouldShowUIBarsOnScrollUp;      // default = YES

@property (nonatomic) BOOL shouldHideNavigationBarOnScroll; // default = YES
@property (nonatomic) BOOL shouldHideToolbarOnScroll;       // default = YES
@property (nonatomic) BOOL shouldHideTabBarOnScroll;        // default = YES

- (id)initWithViewController:(UIViewController*)viewController
                  scrollView:(UIScrollView*)scrollView;

- (void)showUIBarsAnimated:(BOOL)animated;

// used in UIViewController+YIFullScreenScroll
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;

@end


@protocol YIFullScreenScrollDelegate <NSObject>

@optional
- (void)fullScreenScrollDidLayoutUIBars:(YIFullScreenScroll*)fullScreenScroll;

@end
