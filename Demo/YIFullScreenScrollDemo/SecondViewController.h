//
//  SecondViewController.h
//  YIFullScreenScrollDemo
//
//  Created by Yasuhiro Inami on 12/06/03.
//  Copyright (c) 2012年 Yasuhiro Inami. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SecondViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIToolbar *addressBar;
@property (weak, nonatomic) IBOutlet UITextField *addressField;

@end
