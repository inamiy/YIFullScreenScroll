YIFullScreenScroll 1.3.0
========================

Pinterest-like scroll-to-fullscreen UI for iOS5+ (including iOS7).

<img src="https://raw.github.com/inamiy/YIFullScreenScroll/master/Screenshots/screenshot1.png" alt="ScreenShot1" width="225px" style="width:225px;" />

From version 1.0.0, `YIFullScreenScroll` uses [JRSwizzle](https://github.com/rentzsch/jrswizzle/) to extend `UIViewController`'s functionality, and KVO (Key-Value-Observing) instead of conforming to `UIScrollViewDelegate` for easiler implementation.

There are slight changes in its APIs too, so please see header files for more details.

Install via [CocoaPods](http://cocoapods.org/)
----------

```
pod 'YIFullScreenScroll'
```
    
How to use
----------

```
#import "YIFullScreenScroll.h"

...

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.fullScreenScroll = [[YIFullScreenScroll alloc] initWithViewController:self scrollView:self.tableView];
    self.fullScreenScroll.shouldShowUIBarsOnScrollUp = NO;
    
//    self.fullScreenScroll.shouldHideNavigationBarOnScroll = NO;
//    self.fullScreenScroll.shouldHideToolbarOnScroll = NO;
//    self.fullScreenScroll.shouldHideTabBarOnScroll = NO;
}
```

Style
-----

```
typedef NS_ENUM(NSInteger, YIFullScreenScrollStyle) {
    YIFullScreenScrollStyleDefault,     // no statusBar-background when navBar is hidden
#if defined(__IPHONE_7_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    YIFullScreenScrollStyleFacebook,    // like facebook ver 6.0, remaining navBar for statusBar-background in iOS7
#endif
};
```

UISearchDisplayController issue
-------------------------------

If you are using `UISearchDisplayController` in iOS7, there is a searchBar-bug that doesn't respond to touches when you slightly scrolled down (about searchBar height) and then activate searchDisplayController. To prevent it, call below method on `-searchBarShouldBeginEditing:`.

```
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    // NOTE: this code is needed for iOS7
    [self.fullScreenScroll adjustScrollPositionWhenSearchDisplayControllerBecomeActive];
    
    return YES;
}
```

Dependencies
------------
- [JRSwizzle 1.0](https://github.com/rentzsch/jrswizzle)
- [ViewUtils 1.1](https://github.com/nicklockwood/ViewUtils)

License
-------
`YIFullScreenScroll` is available under the [Beerware](http://en.wikipedia.org/wiki/Beerware) license.

If we meet some day, and you think this stuff is worth it, you can buy me a beer in return.
