//
//  SingleComicViewController.m
//  xkcd
//
//  Created by Joshua Bleecher Snyder on 9/2/09.
//  Copyright 2009 Treeline Labs. All rights reserved.
//

#import <Twitter/Twitter.h>

#import "SingleComicViewController.h"
#import "Comic.h"
#import "ComicImageView.h"
#import "TiledImage.h"
#import "CGGeometry_TLCommon.h"
#import "xkcdAppDelegate.h"
#import "SingleComicImageFetcher.h"
#import "ComicListViewController.h"
#import "TLLoadingView.h"
#import "UIBarButtonItem_TLCommon.h"
#import "TLMersenneTwister.h"
#import "UIViewController_TLCommon.h"
#import "LambdaSheet.h"

#define kTileWidth 1024.0f
#define kTileHeight 1024.0f
#define kMaxTweetLength 140

#pragma mark -

@interface SingleComicViewController ()

- (void)email;
- (void)tweet;
- (void)toggleToolbarsAnimated:(BOOL)animated;
- (void)goToPreviousComic;
- (void)goToRandomComic;
- (void)goToNextComic;
- (void)displayComicImage;
- (void)setupToolbar;
- (void)displayLoadingView;
- (void)goToComicNumbered:(NSUInteger)comicNumber;
- (void)saveComicImage;

@property(nonatomic, strong, readwrite) Comic *comic;
@property(nonatomic, strong, readwrite) NSMutableArray *comicImageViews;
@property(nonatomic, strong, readwrite) UIView *contentView;
@property(nonatomic, strong, readwrite) UIScrollView *imageScroller;
@property(nonatomic, strong, readwrite) TLLoadingView *loadingView;
@property(nonatomic, strong, readwrite) SingleComicImageFetcher *imageFetcher;
@property(nonatomic, strong, readwrite) TLModalActivityIndicatorView *spinner;

@end

#pragma mark -

@implementation SingleComicViewController

@synthesize comic;
@synthesize comicImageViews;
@synthesize contentView;
@synthesize imageScroller;
@synthesize loadingView;
@synthesize imageFetcher;
@synthesize spinner;

- (id)initWithComic:(Comic *)comicToView {
  if(self = [super initWithNibName:nil bundle:nil]) {
    self.comic = comicToView;
    self.title = self.comic.name;
  }
  return self;
}

- (void)loadView {
  [super loadView];
  self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupToolbar];
  
  if([self.comic hasBeenDownloaded]) {
    [self displayComicImage];    
  } else {
    [self displayLoadingView];
    self.imageFetcher = [[SingleComicImageFetcher alloc] init];
    self.imageFetcher.delegate = self;    
    [self.imageFetcher fetchImageForComic:self.comic context:nil];
  }
}

- (void)setupToolbar {
  UIBarButtonItem *systemActionItem = [UIBarButtonItem barButtonSystemItem:UIBarButtonSystemItemAction
                                                                    target:self
                                                                    action:@selector(systemAction:)];
  UIBarButtonItem *shareToolbarItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"glyphish_chat"]
                                                                        style:UIBarButtonItemStylePlain
                                                                       target:self
                                                                       action:@selector(share:)];
  
  UIBarButtonItem *previousItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"down"]
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(goToPreviousComic)];
  if([self.comic.number unsignedIntegerValue] == kMinComicNumber) {
    previousItem.enabled = NO;
  }
  UIBarButtonItem *randomItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"glyphish_shuffle"]
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(goToRandomComic)];
  UIBarButtonItem *nextItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"up"]
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(goToNextComic)];
  if([self.comic.number unsignedIntegerValue] == [[Comic lastKnownComic].number unsignedIntegerValue]) {
    nextItem.enabled = NO;
  }
  
  NSArray *toolbarItems = [NSArray arrayWithObjects:
                           systemActionItem,
                           [UIBarButtonItem flexibleSpaceBarButtonItem],
                           shareToolbarItem,
                           [UIBarButtonItem flexibleSpaceBarButtonItem],
                           [UIBarButtonItem flexibleSpaceBarButtonItem],
                           previousItem,
                           [UIBarButtonItem flexibleSpaceBarButtonItem],
                           randomItem,
                           [UIBarButtonItem flexibleSpaceBarButtonItem],
                           nextItem,
                           nil];
  
  [self setToolbarItems:toolbarItems animated:NO];
  [self.navigationController setToolbarHidden:NO animated:NO];  
}

- (void)displayComicImage {
  // Load up the comic image/view
  UIImage *comicImage = self.comic.image;
  CGSize contentSize = comicImage.size;
  TiledImage *tiles = [[TiledImage alloc] initWithImage:comicImage tileWidth:kTileWidth tileHeight:kTileHeight];
  self.contentView = [[UIView alloc] initWithFrame:CGRectZeroWithSize(contentSize)];
  self.comicImageViews = [NSMutableArray arrayWithCapacity:(tiles.widthCount * tiles.heightCount)];
  for(NSUInteger x = 0; x < tiles.widthCount; ++x) {
    for(NSUInteger y = 0; y < tiles.heightCount; ++y) {
      ComicImageView *comicImageView = [[ComicImageView alloc] initWithImage:[tiles imageAtXIndex:x YIndex:y]];
      comicImageView.frame = CGRectWithXYAndSize(x * kTileWidth, y * kTileHeight, comicImageView.frame.size); // adjust origin appropriately
      comicImageView.titleText = self.comic.titleText;
      comicImageView.delegate = self;
      [self.comicImageViews addObject:comicImageView];
    }
  }
  
  // Scroll view
  self.imageScroller = [[UIScrollView alloc] initWithFrame:self.view.bounds];
  self.imageScroller.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.imageScroller.backgroundColor = [UIColor whiteColor];
  self.imageScroller.delaysContentTouches = NO;
  self.imageScroller.alwaysBounceVertical = YES;
  self.imageScroller.alwaysBounceHorizontal = YES;
  self.imageScroller.delegate = self;
  self.imageScroller.bouncesZoom = YES;
  self.imageScroller.scrollEnabled = YES;
  self.imageScroller.scrollsToTop = NO;
  [self.view addSubview:self.imageScroller];
  
  self.imageScroller.contentSize = contentSize;
  self.imageScroller.maximumZoomScale = 2;
  CGFloat xMinZoom = imageScroller.frame.size.width / contentSize.width;
  CGFloat yMinZoom = imageScroller.frame.size.height / contentSize.height;
  self.imageScroller.minimumZoomScale = (xMinZoom < yMinZoom) ? xMinZoom : yMinZoom;
  for(UIView *tileView in self.comicImageViews) {
    [self.contentView addSubview:tileView];
  }
  [self.imageScroller addSubview:self.contentView];
  
  if([AppDelegate openZoomedOut]) {
    [self.imageScroller setZoomScale:self.imageScroller.minimumZoomScale animated:NO];
  }
}

- (void)displayLoadingView {
  self.loadingView = [[TLLoadingView alloc] initWithFrame:self.view.bounds];
  self.loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.loadingView setNeedsLayout];
  [self.view addSubview:self.loadingView];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  [super shouldAutorotateToInterfaceOrientation:interfaceOrientation];
  return [AppDelegate rotate] ? (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown)
  : (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)viewDidUnload {
  self.imageScroller = nil;
  self.contentView = nil;
  self.loadingView = nil;
}

- (void)dealloc {
  comic = nil;
  contentView = nil;
  comicImageViews = nil;
  imageScroller = nil;
  loadingView = nil;
  imageFetcher.delegate = nil;
  imageFetcher = nil;
  spinner = nil;
  
}

- (void)toggleToolbarsAnimated:(BOOL)animated {
  BOOL toolbarIsHidden = self.navigationController.toolbarHidden;
  [self.navigationController setToolbarHidden:!toolbarIsHidden animated:animated];
  [self.navigationController setNavigationBarHidden:!toolbarIsHidden animated:animated];  
}

- (void)share:(UIBarButtonItem *)sender {
  LambdaSheet *sheet = [[LambdaSheet alloc] initWithTitle:NSLocalizedString(@"Share link to this comic", @"Action sheet title")];
  if([MFMailComposeViewController canSendMail]) {
    [sheet addButtonWithTitle:NSLocalizedString(@"Email", @"Action sheet title")
                        block:^void {
                          [self email];
                        }];
  }
  if([TWTweetComposeViewController canSendTweet]) {
    [sheet addButtonWithTitle:NSLocalizedString(@"Twitter", @"Action sheet title")
                        block:^void {
                          [self tweet];
                        }];   
  }
  [sheet addCancelButton];
  [sheet showFromToolbar:self.navigationController.toolbar];
}

- (void)systemAction:(UIBarButtonItem *)sender {
  LambdaSheet *sheet = [[LambdaSheet alloc] initWithTitle:nil];
  if([self.comic hasBeenDownloaded]) {
    [sheet addButtonWithTitle:NSLocalizedString(@"Save to Photos", @"Action sheet title")
                        block:^void {
                          [self saveComicImage];
                        }];
  }
  [sheet addButtonWithTitle:NSLocalizedString(@"Open in Safari", @"Action sheet title")
                      block:^void {
                        NSURL *comicURL = [NSURL URLWithString:[self.comic websiteURL]];
                        [[UIApplication sharedApplication] openURL:comicURL];
                      }];
  [sheet addCancelButton];
  [sheet showFromToolbar:self.navigationController.toolbar];
}

- (void)goToPreviousComic {
  [self goToComicNumbered:([self.comic.number unsignedIntegerValue] - 1)];
}

- (void)goToRandomComic {
  NSUInteger maxComicNumber = [[Comic lastKnownComic].number unsignedIntegerValue];
  long randNumber = [TLMersenneTwister randInt31];
  NSUInteger randomComicNumber = randNumber % (maxComicNumber - kMinComicNumber) + kMinComicNumber;
  [self goToComicNumbered:randomComicNumber];
}

- (void)goToNextComic {
  [self goToComicNumbered:([self.comic.number unsignedIntegerValue] + 1)];
}

- (void)goToComicNumbered:(NSUInteger)comicNumber {
  // UGLY
  NSMutableArray *viewControllerStack = [self.navigationController.viewControllers mutableCopy];
  Comic *newComic = [Comic comicNumbered:comicNumber];
  SingleComicViewController *newSingleComicViewController = [[SingleComicViewController alloc] initWithComic:newComic]; 
  [viewControllerStack replaceObjectAtIndex:[viewControllerStack count] - 1
                                 withObject:newSingleComicViewController];
  [self.navigationController setViewControllers:viewControllerStack animated:NO];

  // deselect any selected rows, to avoid ugliness (still kinda ugly, but it'll have to be good enough for now, need to release)
  ComicListViewController *comicList = [viewControllerStack objectAtIndex:0];
  [comicList.tableView deselectRowAtIndexPath:[comicList.tableView indexPathForSelectedRow] animated:NO];
}

- (void)saveComicImage {
  self.spinner = [[TLModalActivityIndicatorView alloc] initWithText:NSLocalizedString(@"Saving to Photos", @"Modal spinner text for saving to Photos.app")];
  [self.spinner show];
  UIImageWriteToSavedPhotosAlbum(self.comic.image,
                                 self,
                                 @selector(image:didFinishSavingWithError:contextInfo:),
                                 nil);
}

#pragma mark -
#pragma mark UIImageWriteToSavedPhotosAlbum delegate methods

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
  [self.spinner dismiss];
  self.spinner = nil;
}

#pragma mark -
#pragma mark SingleComicImageFetcherDelegate methods

- (void)singleComicImageFetcher:(SingleComicImageFetcher *)fetcher
          didFetchImageForComic:(Comic *)comic
                        context:(id)context {
  self.imageFetcher = nil;
  [self.loadingView removeFromSuperview];
  [self displayComicImage];
}

- (void)singleComicImageFetcher:(SingleComicImageFetcher *)fetcher
               didFailWithError:(NSError *)error
                        onComic:(Comic *)comic {
  [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark UIScrollViewDelegate methods

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
  return contentView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
}

#pragma mark -
#pragma mark ComicImageViewDelegate

- (void)zoomOutWithTouch:(UITouch *)touch {
  CGFloat newZoomScale = MIN(self.imageScroller.zoomScale * 1.5, self.imageScroller.maximumZoomScale);
  [self.imageScroller setZoomScale:newZoomScale animated:YES];
}

- (void)didDetectShortSingleTap {
  [self toggleToolbarsAnimated:YES];
}

#pragma mark -
#pragma mark Action sheet supporting actions

- (void)email {
  MFMailComposeViewController *emailViewController = [[MFMailComposeViewController alloc] initWithNibName:nil bundle:nil];
  emailViewController.mailComposeDelegate = self;
  [emailViewController setSubject:comic.name];
  
  NSString *messageBody = [NSString stringWithFormat:NSLocalizedString(@"<a href=\"%@\">%@</a><br/><br/><br/>Via the <a href=\"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=303688284&mt=8\">xkcd iPhone app</a>",
                                                                       @"Body of share comic email."), [comic websiteURL], [comic websiteURL]];
  [emailViewController setMessageBody:messageBody isHTML:YES];
  [self presentViewController:emailViewController animated:YES completion:^{}];
}

- (void)tweet {
  TWTweetComposeViewController *composer = [[TWTweetComposeViewController alloc] init];
  [composer addURL:[NSURL URLWithString:comic.websiteURL]];
  [self presentViewController:composer animated:YES completion:^{}];
}

#pragma mark -
#pragma mark MFMailComposeViewControllerDelegate methods

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
  [controller dismissViewControllerAnimated:YES completion:^{}];
}

@end
