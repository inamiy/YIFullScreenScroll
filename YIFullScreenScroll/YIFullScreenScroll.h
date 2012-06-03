//
//  YIFullScreenScroll.h
//  YIFullScreenScroll
//
//  Created by Yasuhiro Inami on 12/06/03.
//  Copyright (c) 2012 Yasuhiro Inami. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YIFullScreenScroll : NSObject <UIScrollViewDelegate>
{
    CGFloat _prevContentOffsetY;
    
    BOOL    _isScrollingTop;
}

@property (strong, nonatomic) UIViewController* viewController;

@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL shouldShowUIBarsOnScrollUp;

- (id)initWithViewController:(UIViewController*)viewController;

- (void)layoutTabBarController; // set on viewDidAppear, if using tabBarController

- (void)showUIBarsWithScrollView:(UIScrollView*)scrollView animated:(BOOL)animated;

@end
