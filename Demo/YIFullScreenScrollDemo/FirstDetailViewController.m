//
//  FirstDetailViewController.m
//  YIFullScreenScrollDemo
//
//  Created by Inami Yasuhiro on 13/05/13.
//  Copyright (c) 2013年 Yasuhiro Inami. All rights reserved.
//

#import "FirstDetailViewController.h"

#define ENABLE_FULLSCREEN   1

@interface FirstDetailViewController ()

@end

@implementation FirstDetailViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
#if ENABLE_FULLSCREEN
    self.fullScreenScroll = [[YIFullScreenScroll alloc] initWithViewController:self scrollView:self.scrollView];
    self.fullScreenScroll.shouldShowUIBarsOnScrollUp = NO;
    
    CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
    
    // set insets first before setting contentSize
    self.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(navBarHeight, 0, 0, 0);
    self.scrollView.contentInset = UIEdgeInsetsMake(navBarHeight, 0, 0, 0);
#endif
    
    self.scrollView.contentSize = ((UIView*)self.scrollView.subviews[0]).bounds.size;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    [self setScrollView:nil];
    [super viewDidUnload];
}
@end
