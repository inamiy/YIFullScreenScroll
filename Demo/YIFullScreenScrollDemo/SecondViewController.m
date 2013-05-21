//
//  SecondViewController.m
//  YIFullScreenScrollDemo
//
//  Created by Yasuhiro Inami on 12/06/03.
//  Copyright (c) 2012年 Yasuhiro Inami. All rights reserved.
//

#import "SecondViewController.h"

@interface SecondViewController () <UIWebViewDelegate, YIFullScreenScrollDelegate>

@end

@implementation SecondViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(self.addressBar.frame.size.height, 0, 0, 0);
    self.webView.scrollView.contentInset = UIEdgeInsetsMake(self.addressBar.frame.size.height, 0, 0, 0);
    
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com/search?q=YIFullScreenScroll"]];
//    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.cocoacontrols.com/controls/yifullscreenscroll"]];
    
    [self.webView loadRequest:request];
    
    self.fullScreenScroll = [[YIFullScreenScroll alloc] initWithViewController:self scrollView:self.webView.scrollView];
    self.fullScreenScroll.delegate = self;
    
    self.fullScreenScroll.shouldShowUIBarsOnScrollUp = NO;
    
    // this property controls hiding UI-bars via UIWebView's JavaScript calling window.scrollTo(0,1))
    self.fullScreenScroll.shouldHideUIBarsWhenNotDragging = YES;
    
    self.fullScreenScroll.shouldHideTabBarOnScroll = NO;    // fix tabBar position
}

- (void)viewDidUnload
{
    [self setWebView:nil];
    [self setAddressBar:nil];
    [self setAddressField:nil];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark -

#pragma mark UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.addressField.text = webView.request.URL.absoluteString;
}

#pragma mark -

#pragma mark YIFullScreenScrollDelegate

- (void)fullScreenScrollDidLayoutUIBars:(YIFullScreenScroll *)fullScreenScroll
{
    CGFloat offsetY = self.webView.scrollView.contentOffset.y+self.webView.scrollView.contentInset.top;
    
    // adjust addressBar
    // (-addressBar.height <= addressBar.frame.origin.y <= 0 (default))
    CGRect frame = self.addressBar.frame;
    frame.origin.y = MIN(MAX(-offsetY, -self.addressBar.frame.size.height), 0);
    self.addressBar.frame = frame;
    
    // adjust scrollInsets.top
    // (0 <= scrollInsets.top <= addressBar.frame.size.height (default))
    UIEdgeInsets scrollInsets = self.webView.scrollView.scrollIndicatorInsets;
    scrollInsets.top = MIN(MAX(self.addressBar.frame.size.height-offsetY, 0), self.addressBar.frame.size.height);
    self.webView.scrollView.scrollIndicatorInsets = scrollInsets;
}

@end
