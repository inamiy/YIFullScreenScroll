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
{
    YIFullScreenScroll* _fullScreenDelegate;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _fullScreenDelegate = [[YIFullScreenScroll alloc] initWithViewController:self];
    _fullScreenDelegate.shouldShowUIBarsOnScrollUp = YES;
    
    // pulldown dummy view (red)
    // TODO: avoid navBar-translucency when rotating
    UIView *pulldownDummyView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, self.view.frame.size.width, self.tableView.bounds.size.height)];
    pulldownDummyView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    pulldownDummyView.backgroundColor = [UIColor redColor];
    [self.tableView addSubview:pulldownDummyView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.toolbarItems.count == 0) {
        [self.navigationController setToolbarHidden:YES animated:animated];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.toolbarItems.count > 0) {
        [self.navigationController setToolbarHidden:NO animated:animated];
    }
    
    // set on viewDidAppear, if using tabBarController
    [_fullScreenDelegate layoutTabBarController];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    _fullScreenDelegate = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)didReceiveMemoryWarning
{
    // make sure to release before viewController deallocates!
    _fullScreenDelegate = nil;
}

#pragma mark -

#pragma mark IBActions

- (IBAction)handleToggleButton:(id)sender
{
    if (_fullScreenDelegate.enabled) {
        [_fullScreenDelegate showUIBarsWithScrollView:self.tableView animated:NO];
    }
    
    _fullScreenDelegate.enabled = !_fullScreenDelegate.enabled;
}

- (IBAction)handleTintColorButton:(id)sender
{
    UIColor* randomColor = [UIColor colorWithHue:(arc4random()%100)/100.0 saturation:1 brightness:1 alpha:1];
    
    self.navigationController.navigationBar.tintColor = randomColor;
    self.navigationController.toolbar.tintColor = randomColor;
}

#pragma mark -

#pragma mark Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // hide tabBar when pushed & show again when popped
    self.hidesBottomBarWhenPushed = YES;
    
    double delayInSeconds = UINavigationControllerHideShowBarDuration;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        self.hidesBottomBarWhenPushed = NO;
    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 20;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Configure the cell...
    cell.textLabel.text = [NSString stringWithFormat:@"%d-%d (%d)",indexPath.section,indexPath.row,arc4random()];
    
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
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
    
//    [self.navigationController setNavigationBarHidden:NO animated:YES];
//    [self.tabBarController setTabBarHidden:NO animated:YES];
    
    [_fullScreenDelegate showUIBarsWithScrollView:tableView animated:YES];
    
    [self handleTintColorButton:nil];
}

#pragma mark -

#pragma mark UIScrollViewDelegate

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [_fullScreenDelegate scrollViewWillBeginDragging:scrollView];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
//    LOG_INT(self.tableView.tracking);
//    LOG_INT(self.tableView.dragging);
//    LOG_INT(self.tableView.decelerating);
    
    [_fullScreenDelegate scrollViewDidScroll:scrollView];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    [_fullScreenDelegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    return [_fullScreenDelegate scrollViewShouldScrollToTop:scrollView];;
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView
{
    [_fullScreenDelegate scrollViewDidScrollToTop:scrollView];
}

@end
