//
//  UIViewController+YIFullScreenScroll.m
//  YIFullScreenScrollDemo
//
//  Created by Inami Yasuhiro on 13/04/15.
//  Copyright (c) 2013年 Yasuhiro Inami. All rights reserved.
//

#import "UIViewController+YIFullScreenScroll.h"
#import "YIFullScreenScroll.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>

static const char __fullScreenScrollKey;


@implementation UIViewController (YIFullScreenScroll)

#pragma mark Accessors

- (YIFullScreenScroll*)fullScreenScroll
{
    return objc_getAssociatedObject(self, &__fullScreenScrollKey);
}

- (void)setFullScreenScroll:(YIFullScreenScroll*)fullScreenScroll
{
    objc_setAssociatedObject(self, &__fullScreenScrollKey, fullScreenScroll, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

#pragma mark Swizzling

+ (void)load
{
    [UIViewController jr_swizzleMethod:@selector(viewWillAppear:)
                            withMethod:@selector(YIFullScreenScroll_viewWillAppear:)
                                 error:NULL];
    
    [UIViewController jr_swizzleMethod:@selector(viewDidAppear:)
                            withMethod:@selector(YIFullScreenScroll_viewDidAppear:)
                                 error:NULL];
    
    [UIViewController jr_swizzleMethod:@selector(viewWillDisappear:)
                            withMethod:@selector(YIFullScreenScroll_viewWillDisappear:)
                                 error:NULL];
    
    [UIViewController jr_swizzleMethod:@selector(viewDidDisappear:)
                            withMethod:@selector(YIFullScreenScroll_viewDidDisappear:)
                                 error:NULL];
    
    [UIViewController jr_swizzleMethod:@selector(willRotateToInterfaceOrientation:duration:)
                            withMethod:@selector(YIFullScreenScroll_willRotateToInterfaceOrientation:duration:)
                                 error:NULL];
}

- (void)YIFullScreenScroll_viewWillAppear:(BOOL)animated
{
    [self YIFullScreenScroll_viewWillAppear:animated];
    [self.fullScreenScroll viewWillAppear:animated];
}

- (void)YIFullScreenScroll_viewDidAppear:(BOOL)animated
{
    [self YIFullScreenScroll_viewDidAppear:animated];
    [self.fullScreenScroll viewDidAppear:animated];
}

- (void)YIFullScreenScroll_viewWillDisappear:(BOOL)animated
{
    [self YIFullScreenScroll_viewWillDisappear:animated];
    [self.fullScreenScroll viewWillDisappear:animated];
}

- (void)YIFullScreenScroll_viewDidDisappear:(BOOL)animated
{
    [self YIFullScreenScroll_viewDidDisappear:animated];
    [self.fullScreenScroll viewDidDisappear:animated];
}

- (void)YIFullScreenScroll_willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self YIFullScreenScroll_willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.fullScreenScroll willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

@end
