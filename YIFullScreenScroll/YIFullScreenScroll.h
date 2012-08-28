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

@property (weak, nonatomic) UIViewController* viewController;

@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL shouldShowUIBarsOnScrollUp;

//
// NOTE:
// YIFullScreenScroll forces viewController.navigationController's navigationBar/toolbar 
// to set translucent=YES (to set navigationController's content size wider for convenience).
//
- (id)initWithViewController:(UIViewController*)viewController; // default: ignoreTranslucent=YES
- (id)initWithViewController:(UIViewController*)viewController ignoreTranslucent:(BOOL)ignoreTranslucent;

- (void)layoutTabBarController; // set on viewDidAppear, if using tabBarController

- (void)showUIBarsWithScrollView:(UIScrollView*)scrollView animated:(BOOL)animated;

@end
