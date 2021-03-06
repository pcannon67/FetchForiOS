//
//  UrlListViewController.m
//  Fetch
//
//  Created by Josh on 9/26/13.
//  Copyright (c) 2013 Jukaela Enterprises. All rights reserved.
//

#import "UrlListViewController.h"
#import "Projects.h"
#import "Urls.h"
#import "Constants.h"
#import "AppDelegate.h"
#import "URLCell.h"
#import "NSTimer+Blocks.h"
#import "Reachability.h"
#import "NSString+Extensions.h"

@interface UrlListViewController ()

/**
 *  Mutable array that holds a list of Url object
 */
@property (strong, nonatomic) NSMutableArray *urlList;

/**
 *  NSTimer that checks the reachability status of the Url objects contained in urlCellArray
 */
@property (strong, nonatomic) NSTimer *pingTimer;

/**
 *  Mutable array that holds a reference to the UrlCells that are currently displayed.
 *  This is important to do because you need to have a list of UrlCells that are currently
 *  displayed to be a able to update the status images.
 */
@property (strong, nonatomic) NSMutableArray *urlCellArray;

/**
 *  Creates an NSTimer object that fires at the specified interval
 *
 *  @param timeInterval The timer interval to wait between firings.
 */
-(void)createTimerWithTimeInterval:(NSTimeInterval)timeInterval;

/**
 *  Checks the urlString for Reachability status
 *
 *  @param urlString The url to check the reachability status of
 *
 *  @return NetworkStatus enum value.
 */
-(NetworkStatus)urlVerification:(NSString *)urlString;

/**
 *  The application's documents directory
 *
 *  @return NSURL file path of the application's documents directory
 */
- (NSURL *)applicationDocumentsDirectory;

/**
 *  Handle the internet down notification
 *
 *  @param aNotification The notification that is sent
 */
-(void)internetDown:(NSNotification *)aNotification;

/**
 *  Handle the internet up notification
 *
 *  @param aNotification The notification that is sent
 */
-(void)internetUp:(NSNotification *)aNotification;

/**
 *  Reload the RELOAD_TABLE notification
 *
 *  @param aNotification The notification to handle
 */
-(void)reloadTable:(NSNotification *)aNotification;

@end

@implementation UrlListViewController

#pragma mark -
#pragma mark - Lifecycle

- (void)awakeFromNib
{
    [self setClearsSelectionOnViewWillAppear:NO];
    [self setPreferredContentSize:CGSizeMake(320, 600)];
    
    [self setUrlList:[NSMutableArray array]];
    
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if (![self urlCellArray]) {
        [self setUrlCellArray:[NSMutableArray array]];
    }
    
    if ([(AppDelegate *)[[UIApplication sharedApplication] delegate] isInternetDown]) {
        [[[self navigationController] navigationBar] setBarTintColor:[UIColor redColor]];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetDown:) name:INTERNET_DOWN object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetUp:) name:INTERNET_UP object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable:) name:RELOAD_PROJECT_TABLE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable:) name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:nil];

    [self reloadTable:nil];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:INTERNET_DOWN object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:INTERNET_UP object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:RELOAD_PROJECT_TABLE object:nil];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self createTimerWithTimeInterval:10];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [_pingTimer invalidate];
    [self setPingTimer:nil];
    
    [[self urlCellArray] removeAllObjects];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - Methods

-(void)reloadTable:(NSNotification *)aNotification
{
    [[self urlList] removeAllObjects];
    
    [[self pingTimer] invalidate];
    
    [self setUrlList:[NSMutableArray arrayWithArray:[[[[self currentProject] urls] allObjects] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]]]]];
    
    [[self tableView] reloadData];
}

-(void)internetDown:(NSNotification *)aNotification
{
    [[[self navigationController] navigationBar] setBarTintColor:[UIColor redColor]];
}

-(void)internetUp:(NSNotification *)aNotification
{
    [[[self navigationController] navigationBar] setBarTintColor:[UIColor clearColor]];
}

#pragma mark - IBActions

-(IBAction)addUrl:(id)sender
{
    if ([self currentProject]) {
        Urls *tempUrl = [Urls create];
        
        [[self currentProject] addUrlsObject:tempUrl];
        
        [[self currentProject] save];
        
        [[self urlList] addObject:tempUrl];
        
        [[self tableView] reloadData];
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self urlList] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"URLCell";
    URLCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[URLCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    Urls *tempUrl = [self urlList][[indexPath row]];
    
    if ([[tempUrl urlDescription] length] > 0) {
        [[cell textLabel] setText:[tempUrl urlDescription]];
    }
    else {
        [[cell textLabel] setText:@"No Description"];
    }
    
    [cell setCurrentUrl:tempUrl];
    [[tempUrl siteStatus] isEqualToString:@"Bad"] ? [cell setStatus:URLDown] : [cell setStatus:URLUp];

    [[cell imageView] setImage:[UIImage imageNamed:@"URL"]];
    
    if ([tempUrl favIcon]) {
        NSData *imageData = [NSData dataWithContentsOfFile:[tempUrl favIcon]];
        UIImage *image = [UIImage imageWithData:imageData];
        
        [[cell imageView] setImage:image];
    }
    else {
        NSString *url = [[NSURL URLWithString:[tempUrl url]] host];
        NSString *faviconUrl = [NSString stringWithFormat:@"http://%i.fvicon.com/%@?canAudit=false", arc4random_uniform(9), url];
        
        [[[NSURLSession sharedSession] downloadTaskWithURL:[NSURL URLWithString:faviconUrl] completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (location) {
                    NSData *imageData = [NSData dataWithContentsOfURL:location];
                    UIImage *downloadedImage = [UIImage imageWithData:imageData];
                    
                    if (downloadedImage && [imageData length] != 2251) {
                        NSString *path = [[[self applicationDocumentsDirectory] path] stringByAppendingPathComponent:[location lastPathComponent]];
                        
                        [tempUrl setFavIcon:[[[self applicationDocumentsDirectory] path] stringByAppendingPathComponent:[location lastPathComponent]]];
                        [tempUrl save];
                        
                        dispatch_queue_t lowQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);

                        dispatch_async(lowQueue, ^{
                            [imageData writeToFile:path atomically:YES];
                        });
                        
                        [[cell imageView] setImage:downloadedImage];
                    }
                }
            });
        }] resume];
    }
    
    [[self urlCellArray] addObject:cell];
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Urls *tempUrl = [self urlList][[indexPath row]];
        
        [[self urlList] removeObject:tempUrl];
        
        [tempUrl delete];
        
        [[self tableView] beginUpdates];
        [[self tableView] deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [[self tableView] endUpdates];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Urls *tempUrl = [self urlList][[indexPath row]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:LOAD_URL object:nil userInfo:@{@"url": tempUrl}];
}

#pragma mark
#pragma mark UrlCell Handlers

-(void)createTimerWithTimeInterval:(NSTimeInterval)timeInterval
{
    _pingTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval block:^{
        
        for (URLCell *cell in [self urlCellArray]) {
            __block __weak URLCell *tempCell = cell;
            
            if (![[[tempCell currentUrl] url] isEqualToString:[NSString blankString]]) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    NetworkStatus status = [self urlVerification:[[tempCell currentUrl] url]];
                    
                    if (status != NotReachable) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [tempCell setStatus:URLUp];
                            
                            [[tempCell currentUrl] setSiteStatus:@"Good"];
                            [[tempCell currentUrl] save];
                        });
                    }
                    else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [tempCell setStatus:URLDown];
                            
                            [[tempCell currentUrl] setSiteStatus:@"Bad"];
                            [[tempCell currentUrl] save];
                        });
                    }
                });
            }
        }
    } repeats:YES];
}

-(NetworkStatus)urlVerification:(NSString *)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    
    Reachability *reachability = [Reachability reachabilityWithHostName:[url host]];
    
    NetworkStatus status = [reachability currentReachabilityStatus];
    
    return status;
}

- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}
@end
