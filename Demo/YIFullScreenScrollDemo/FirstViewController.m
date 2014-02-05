//
//  FirstViewController.m
//  YIFullScreenScrollDemo
//
//  Created by Yasuhiro Inami on 12/06/03.
//  Copyright (c) 2012年 Yasuhiro Inami. All rights reserved.
//

#import "FirstViewController.h"

@interface FirstViewController ()

@end

@implementation FirstViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"%s", __func__);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.searchDisplayController.searchResultsTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    
    self.fullScreenScroll = [[YIFullScreenScroll alloc] initWithViewController:self scrollView:self.tableView style:YIFullScreenScrollStyleFacebook];
    self.fullScreenScroll.shouldShowUIBarsOnScrollUp = NO;
    
//    self.fullScreenScroll.shouldHideNavigationBarOnScroll = NO;
//    self.fullScreenScroll.shouldHideToolbarOnScroll = NO;
//    self.fullScreenScroll.shouldHideTabBarOnScroll = NO;
    
//    self.fullScreenScroll.additionalOffsetYToStartHiding = 200;
//    self.fullScreenScroll.additionalOffsetYToStartShowing = 100;
    
    // pulldown dummy view
    // TODO: avoid navBar-translucency when rotating
    UIView *pulldownDummyView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, self.view.frame.size.width, self.tableView.bounds.size.height)];
    pulldownDummyView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    pulldownDummyView.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    [self.tableView addSubview:pulldownDummyView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.toolbarItems.count > 0) {
        [self.navigationController setToolbarHidden:NO animated:animated];
    }
    else {
        [self.navigationController setToolbarHidden:YES animated:animated];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

#pragma mark -

#pragma mark IBActions

- (IBAction)handleToggleButton:(id)sender
{
    self.fullScreenScroll.enabled = !self.fullScreenScroll.enabled;
}

- (IBAction)handleModalPresentButton:(id)sender
{
    UIBarButtonItem* modalCloseItem = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStyleDone target:self action:@selector(handleModalDismissButton:)];
    
    UINavigationController* modalNavC = [self.storyboard instantiateViewControllerWithIdentifier:@"NavigationController"];
    modalNavC.topViewController.navigationItem.leftBarButtonItem = modalCloseItem;
    [self presentViewController:modalNavC animated:YES completion:NULL];
}

- (IBAction)handleModalDismissButton:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)handleTintColorButton:(id)sender
{
    UIColor* randomColor = [UIColor colorWithHue:(arc4random()%100)/100.0 saturation:0.8 brightness:0.8 alpha:1];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if ([self.navigationController.navigationBar respondsToSelector:@selector(barTintColor)]) {
        self.navigationController.navigationBar.barTintColor = randomColor;
        self.navigationController.toolbar.barTintColor = randomColor;
        
        return;
    }
#endif
    
    self.navigationController.navigationBar.tintColor = randomColor;
    self.navigationController.toolbar.tintColor = randomColor;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    }
    
    return 50;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (indexPath.section == 0) {
        cell.textLabel.text = @"Show in Modal";
        return cell;
    }
    
    // Configure the cell...
    cell.textLabel.text = [NSString stringWithFormat:@"Cell %d-%d",indexPath.section,indexPath.row];
    
    return cell;
}

/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
 {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
 }   
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }   
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        [self handleModalPresentButton:nil];
        return;
    }
    
    [self.fullScreenScroll showUIBarsAnimated:YES];
    
    [self handleTintColorButton:nil];
}

//
// WARNING:
// Don't use UITableView's titleForHeader/FooterInSection when using YIFullScreenScroll,
// since this library's core concept is to initially expand scrollView's frame
// till navigationBar/toolbar's frames by force-setting translucent=YES.
// 
// See also:
// The first section is under navigation bar,when tableview have sections.:
// https://github.com/inamiy/YIFullScreenScroll/issues/3
//
//- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{
//    if (section == 0) {
//        return @"Show in Modal";
//    }
//    
//    return @"Tints Color";
//}

#pragma mark -

#pragma mark UISearchBarDelegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    // NOTE: this code is needed for iOS7
    [self.fullScreenScroll adjustScrollPositionWhenSearchDisplayControllerBecomeActive];
    
    return YES;
}

@end
