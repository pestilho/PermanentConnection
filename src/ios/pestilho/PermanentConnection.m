#import "PermanentConnection.h"

#import "HWIFileDownloader.h"
#import "HWIFileDownloadProgress.h"
#import "HWIFileDownloadItem.h"
#import "HWIFileDownloadDelegate.h"
#import "HWIBackgroundSessionCompletionHandlerBlock.h"

#import <Cordova/CDVAvailability.h>
#import <UIKit/UIKit.h>

#import "PluginDownloadItem.h"
#import "PluginDownloadNotifications.h"
#import "HWIFileDownloadProgress.h"

static void *PluginDownloadStoreProgressObserverContext = &PluginDownloadStoreProgressObserverContext;

@interface PermanentConnection()
@property (nonnull, nonatomic, strong, readwrite) HWIFileDownloader *fileDownloader;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier; // iOS 6

@property (nonatomic, assign) NSUInteger networkActivityIndicatorCount;
@property (nonatomic, strong, readwrite, nonnull) NSMutableArray<PluginDownloadItem *> *downloadItemsArray;
@property (nonatomic, strong, nonnull) NSProgress *progress;

@property (nonatomic, strong, readwrite) CDVInvokedUrlCommand *callbackcommand;
@property (nonatomic, strong, readwrite) PluginDownloadItem *actualDownloadItem;
@end

@implementation PermanentConnection

- (void)pluginInitialize { 
  self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
  self.networkActivityIndicatorCount = 0;
  self.progress = [NSProgress progressWithTotalUnitCount:0];
  
  if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
  {
      [self.progress addObserver:self
                      forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                          options:NSKeyValueObservingOptionInitial
                          context:PluginDownloadStoreProgressObserverContext];
  }
  
  [self setupDownloadItems];
}

- (void)startdownload:(CDVInvokedUrlCommand *)command {
  self.callbackcommand = command;
  NSInteger randomID = [ self generateRandomNumber ];
  NSString* urlstring = [command.arguments objectAtIndex:0];
  NSString *filename = [NSString stringWithFormat:@"%d", randomID];

  NSURL *aFileDownloadDirectoryURL = nil;
  NSArray *aDocumentDirectoryURLsArray = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
  NSURL *aDocumentsDirectoryURL = [aDocumentDirectoryURLsArray firstObject];
  aFileDownloadDirectoryURL = [aDocumentsDirectoryURL URLByAppendingPathComponent:@"pc-downloads" isDirectory:YES];

  NSString *initresponsestring = [ NSString stringWithFormat: @"{ \"type\" : \"downloadpath\", \"data\" : \"%@\" }", aFileDownloadDirectoryURL.path ];
  CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:initresponsestring];
  [ result setKeepCallbackAsBool:YES ];
  [ self.commandDelegate sendPluginResult:result callbackId:command.callbackId ];
    
  // setup downloader
  if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
  {
      self.fileDownloader = [ [HWIFileDownloader alloc] initWithDelegate:self ];
  }
  else
  {
      self.fileDownloader = [ [HWIFileDownloader alloc] initWithDelegate:self maxConcurrentDownloads:1 ];
  }
  [ self.fileDownloader setupWithCompletion:nil ];
  
  NSURL *aRemoteURL = [NSURL URLWithString:urlstring];
  NSString *aDownloadIdentifier = [NSString stringWithFormat:@"%s", filename];

  PluginDownloadItem *aPluginDownloadItem = [[PluginDownloadItem alloc] initWithDownloadIdentifier:aDownloadIdentifier remoteURL:aRemoteURL];
  self.actualDownloadItem = aPluginDownloadItem;
  [ self.downloadItemsArray addObject:aPluginDownloadItem ];
  [ self startDownloadWithDownloadItem:aPluginDownloadItem ];

  NSString *responsestring = [ NSString stringWithFormat: @"{ \"type\" : \"downloadid\", \"data\" : \"%d\" }", randomID ];
  result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:responsestring];
  [ self.commandDelegate sendPluginResult:result callbackId:command.callbackId ];
}

- (void)pausedownload:(CDVInvokedUrlCommand *)command {
  NSString* downloadid = [command.arguments objectAtIndex:0];
  NSString *aDownloadIdentifier = [NSString stringWithFormat:@"%s", downloadid];
  BOOL isDownloading = [self.fileDownloader isDownloadingIdentifier:aDownloadIdentifier];
  if (isDownloading)
  {
      HWIFileDownloadProgress *aFileDownloadProgress = [self.fileDownloader downloadProgressForIdentifier:aDownloadIdentifier];
      [aFileDownloadProgress.nativeProgress pause];
  }
}

- (void)stopdownload:(CDVInvokedUrlCommand *)command {
  NSString* downloadid = [command.arguments objectAtIndex:0];
  NSString *aDownloadIdentifier = [NSString stringWithFormat:@"%s", downloadid];

  BOOL isDownloading = [self.fileDownloader isDownloadingIdentifier:aDownloadIdentifier];
  if (isDownloading)
  {
      if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
      {
          HWIFileDownloadProgress *aFileDownloadProgress = [self.fileDownloader downloadProgressForIdentifier:aDownloadIdentifier];
          [ aFileDownloadProgress.nativeProgress cancel ];
      }
      else
      {
          [ self.fileDownloader cancelDownloadWithIdentifier:aDownloadIdentifier ];
      }
  }
  else
  {
      // app client bookkeeping
      [self cancelDownloadWithDownloadIdentifier:aDownloadIdentifier];
      
      NSUInteger aFoundDownloadItemIndex = [self.downloadItemsArray indexOfObjectPassingTest:^BOOL(PluginDownloadItem *aPluginDownloadItem, NSUInteger anIndex, BOOL *aStopFlag) {
          if ([aPluginDownloadItem.downloadIdentifier isEqualToString:aDownloadIdentifier])
          {
              return YES;
          }
          return NO;
      }];
      if (aFoundDownloadItemIndex != NSNotFound)
      {
          //NSIndexPath *anIndexPath = [NSIndexPath indexPathForRow:aFoundDownloadItemIndex inSection:0];
          //[self.tableView reloadRowsAtIndexPaths:@[anIndexPath] withRowAnimation:UITableViewRowAnimationNone];
      }
  }

  NSString *responsestring = [ NSString stringWithFormat: @"{ \"type\" : \"downloadstop\", \"data\" : \"%d\" }", downloadid ];
  CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:responsestring];
  [ self.commandDelegate sendPluginResult:result callbackId:command.callbackId ];
  
}

- (void)resumedownload:(CDVInvokedUrlCommand *)command {
  NSString* downloadid = [command.arguments objectAtIndex:0];
  NSString *aDownloadIdentifier = [NSString stringWithFormat:@"%s", downloadid];
  [ self resumeDownloadWithDownloadIdentifier:aDownloadIdentifier ];
}

- (void)stopalldownload:(CDVInvokedUrlCommand *)command {
  NSString *responsestring = [ NSString stringWithFormat: @"{ \"type\" : \"downloadallstop\" }" ];
  CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:responsestring];
  [ self.commandDelegate sendPluginResult:result callbackId:command.callbackId ];
}

-(int)generateRandomNumber{
    int TOTAL_NUMBER = 1000000000;

    int low_bound = 0;
    int high_bound = TOTAL_NUMBER;
    int width = high_bound - low_bound;
    int randomNumber = low_bound + arc4random() % width;

    return randomNumber;
}




- (void)setupDownloadItems
{
    self.downloadItemsArray = [self restoredDownloadItems];
    [self storePluginDownloadItems];
    
    self.downloadItemsArray = [NSMutableArray<PluginDownloadItem *> new];
}


- (void)dealloc
{
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        [self.progress removeObserver:self
                           forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                              context:PluginDownloadStoreProgressObserverContext];
    }
}


#pragma mark - HWIFileDownloadDelegate (mandatory)


- (void)downloadDidCompleteWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                             localFileURL:(nonnull NSURL *)aLocalFileURL
{
    NSUInteger aFoundDownloadItemIndex = [self.downloadItemsArray indexOfObjectPassingTest:^BOOL(PluginDownloadItem *aPluginDownloadItem, NSUInteger anIndex, BOOL *aStopFlag) {
        if ([aPluginDownloadItem.downloadIdentifier isEqualToString:aDownloadIdentifier])
        {
            return YES;
        }
        return NO;
    }];
    PluginDownloadItem *aCompletedDownloadItem = nil;
    if (aFoundDownloadItemIndex != NSNotFound)
    {
        NSLog(@"INFO: Download completed (id: %@) (%@, %d)", aDownloadIdentifier, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
        
        aCompletedDownloadItem = [self.downloadItemsArray objectAtIndex:aFoundDownloadItemIndex];
        aCompletedDownloadItem.status = PluginDownloadItemStatusCompleted;
        [self storePluginDownloadItems];
    }
    else
    {
        NSLog(@"ERR: Completed download item not found (id: %@) (%@, %d)", aDownloadIdentifier, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:downloadDidCompleteNotification object:aCompletedDownloadItem];
}


- (void)downloadFailedWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                               error:(nonnull NSError *)anError
                      httpStatusCode:(NSInteger)aHttpStatusCode
                  errorMessagesStack:(nullable NSArray<NSString *> *)anErrorMessagesStack
                          resumeData:(nullable NSData *)aResumeData
{
    NSUInteger aFoundDownloadItemIndex = [self.downloadItemsArray indexOfObjectPassingTest:^BOOL(PluginDownloadItem *aPluginDownloadItem, NSUInteger anIndex, BOOL *aStopFlag) {
        if ([aPluginDownloadItem.downloadIdentifier isEqualToString:aDownloadIdentifier])
        {
            return YES;
        }
        return NO;
    }];
    PluginDownloadItem *aFailedDownloadItem = nil;
    if (aFoundDownloadItemIndex != NSNotFound)
    {
        aFailedDownloadItem = [self.downloadItemsArray objectAtIndex:aFoundDownloadItemIndex];
        aFailedDownloadItem.lastHttpStatusCode = aHttpStatusCode;
        aFailedDownloadItem.resumeData = aResumeData;
        aFailedDownloadItem.downloadError = anError;
        aFailedDownloadItem.downloadErrorMessagesStack = anErrorMessagesStack;
        
        // download status heuristics
        if (aFailedDownloadItem.status != PluginDownloadItemStatusPaused)
        {
            if (aResumeData.length > 0)
            {
                aFailedDownloadItem.status = PluginDownloadItemStatusInterrupted;
            }
            else if ([anError.domain isEqualToString:NSURLErrorDomain] && (anError.code == NSURLErrorCancelled))
            {
                aFailedDownloadItem.status = PluginDownloadItemStatusCancelled;
            }
            else
            {
                aFailedDownloadItem.status = PluginDownloadItemStatusError;
            }
        }
        [self storePluginDownloadItems];
        
        switch (aFailedDownloadItem.status) {
            case PluginDownloadItemStatusError:
                NSLog(@"ERR: Download with error %@ (http status: %@) - id: %@ (%@, %d)", @(anError.code), @(aHttpStatusCode), aDownloadIdentifier, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
                break;
            case PluginDownloadItemStatusInterrupted:
                NSLog(@"ERR: Download interrupted with error %@ - id: %@ (%@, %d)", @(anError.code), aDownloadIdentifier, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
                break;
            case PluginDownloadItemStatusCancelled:
                NSLog(@"INFO: Download cancelled - id: %@ (%@, %d)", aDownloadIdentifier, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
                break;
            case PluginDownloadItemStatusPaused:
                NSLog(@"INFO: Download paused - id: %@ (%@, %d)", aDownloadIdentifier, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
                break;
                
            default:
                break;
        }
        
    }
    else
    {
        NSLog(@"ERR: Failed download item not found (id: %@) (%@, %d)", aDownloadIdentifier, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:downloadDidCompleteNotification object:aFailedDownloadItem];
}


- (void)incrementNetworkActivityIndicatorActivityCount
{
    [self toggleNetworkActivityIndicatorVisible:YES];
}


- (void)decrementNetworkActivityIndicatorActivityCount
{
    [self toggleNetworkActivityIndicatorVisible:NO];
}


#pragma mark HWIFileDownloadDelegate (optional)


- (void)downloadProgressChangedForIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    NSUInteger aFoundDownloadItemIndex = [self.downloadItemsArray indexOfObjectPassingTest:^BOOL(PluginDownloadItem *aPluginDownloadItem, NSUInteger anIndex, BOOL *aStopFlag) {
        if ([aPluginDownloadItem.downloadIdentifier isEqualToString:aDownloadIdentifier])
        {
            return YES;
        }
        return NO;
    }];
    PluginDownloadItem *aChangedDownloadItem = nil;
    if (aFoundDownloadItemIndex != NSNotFound)
    {
        aChangedDownloadItem = [self.downloadItemsArray objectAtIndex:aFoundDownloadItemIndex];
        HWIFileDownloadProgress *aFileDownloadProgress = [self.fileDownloader downloadProgressForIdentifier:aDownloadIdentifier];
        if (aFileDownloadProgress)
        {
            aChangedDownloadItem.progress = aFileDownloadProgress;
            if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
            {
                aChangedDownloadItem.progress.lastLocalizedDescription = aChangedDownloadItem.progress.nativeProgress.localizedDescription;
                aChangedDownloadItem.progress.lastLocalizedAdditionalDescription = aChangedDownloadItem.progress.nativeProgress.localizedAdditionalDescription;
            }
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:downloadProgressChangedNotification object:aChangedDownloadItem];
}


- (void)downloadPausedWithIdentifier:(nonnull NSString *)aDownloadIdentifier
                          resumeData:(nullable NSData *)aResumeData
{
    NSUInteger aFoundDownloadItemIndex = [self.downloadItemsArray indexOfObjectPassingTest:^BOOL(PluginDownloadItem *aPluginDownloadItem, NSUInteger anIndex, BOOL *aStopFlag) {
        if ([aPluginDownloadItem.downloadIdentifier isEqualToString:aDownloadIdentifier])
        {
            return YES;
        }
        return NO;
    }];
    if (aFoundDownloadItemIndex != NSNotFound)
    {
        NSLog(@"INFO: Download paused - id: %@ (%@, %d)", aDownloadIdentifier, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
        
        PluginDownloadItem *aPausedDownloadItem = [self.downloadItemsArray objectAtIndex:aFoundDownloadItemIndex];
        aPausedDownloadItem.status = PluginDownloadItemStatusPaused;
        aPausedDownloadItem.resumeData = aResumeData;
        [self storePluginDownloadItems];
    }
    else
    {
        NSLog(@"ERR: Paused download item not found (id: %@) (%@, %d)", aDownloadIdentifier, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
    }
}


- (void)resumeDownloadWithIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    NSUInteger aFoundDownloadItemIndex = [self.downloadItemsArray indexOfObjectPassingTest:^BOOL(PluginDownloadItem *aPluginDownloadItem, NSUInteger anIndex, BOOL *aStopFlag) {
        if ([aPluginDownloadItem.downloadIdentifier isEqualToString:aDownloadIdentifier])
        {
            return YES;
        }
        return NO;
    }];
    if (aFoundDownloadItemIndex != NSNotFound)
    {
        PluginDownloadItem *aPluginDownloadItem = [self.downloadItemsArray objectAtIndex:aFoundDownloadItemIndex];
        [self startDownloadWithDownloadItem:aPluginDownloadItem];
    }
}


- (BOOL)downloadAtLocalFileURL:(nonnull NSURL *)aLocalFileURL isValidForDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    BOOL anIsValidFlag = YES;
    
    // just checking for file size
    // you might want to check by converting into expected data format (like UIImage) or by scanning for expected content
    
    NSError *anError = nil;
    NSDictionary <NSString *, id> *aFileAttributesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:aLocalFileURL.path error:&anError];
    if (anError)
    {
        NSLog(@"ERR: Error on getting file size for item at %@: %@ (%@, %d)", aLocalFileURL, anError.localizedDescription, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
        anIsValidFlag = NO;
    }
    else
    {
        unsigned long long aFileSize = [aFileAttributesDictionary fileSize];
        if (aFileSize == 0)
        {
            anIsValidFlag = NO;
        }
        else
        {
            if (aFileSize < 40000)
            {
                NSError *anError = nil;
                NSString *aString = [NSString stringWithContentsOfURL:aLocalFileURL encoding:NSUTF8StringEncoding error:&anError];
                if (anError)
                {
                    NSLog(@"ERR: %@ (%@, %d)", anError.localizedDescription, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
                }
                else
                {
                    NSLog(@"INFO: Downloaded file content for download identifier %@: %@ (%@, %d)", aDownloadIdentifier, aString, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
                }
                anIsValidFlag = NO;
            }
        }
    }
    return anIsValidFlag;
}

/*
- (void)onAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)aChallenge
               downloadIdentifier:(nonnull NSString *)aDownloadIdentifier
                completionHandler:(void (^ _Nonnull)(NSURLCredential * _Nullable aCredential, NSURLSessionAuthChallengeDisposition disposition))aCompletionHandler
{
    if (aChallenge.previousFailureCount == 0)
    {
        NSURLCredential *aCredential = [NSURLCredential credentialWithUser:@"username" password:@"password" persistence:NSURLCredentialPersistenceNone];
        aCompletionHandler(aCredential, NSURLSessionAuthChallengeUseCredential);
    }
    else
    {
        aCompletionHandler(nil, NSURLSessionAuthChallengeRejectProtectionSpace);
    }
}
*/

- (nullable NSProgress *)rootProgress
{
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        return self.progress;
    }
    else
    {
        return nil;
    }
}

/*
- (void)customizeBackgroundSessionConfiguration:(nonnull NSURLSessionConfiguration *)aBackgroundSessionConfiguration
{
    NSMutableDictionary *aHTTPAdditionalHeadersDict = [aBackgroundSessionConfiguration.HTTPAdditionalHeaders mutableCopy];
    if (aHTTPAdditionalHeadersDict == nil) {
        aHTTPAdditionalHeadersDict = [[NSMutableDictionary alloc] init];
    }
    [aHTTPAdditionalHeadersDict setObject:@"identity" forKey:@"Accept-Encoding"];
    aBackgroundSessionConfiguration.HTTPAdditionalHeaders = aHTTPAdditionalHeadersDict;
}
*/

#pragma mark - NSProgress


- (void)observeValueForKeyPath:(nullable NSString *)aKeyPath
                      ofObject:(nullable id)anObject
                        change:(nullable NSDictionary<NSString*, id> *)aChange
                       context:(nullable void *)aContext
{
    if (aContext == PluginDownloadStoreProgressObserverContext)
    {
        NSProgress *aProgress = anObject; // == self.progress
        if ([aKeyPath isEqualToString:@"fractionCompleted"])
        {
            NSLog(@"%@", aProgress);
            NSLog(@"%.20lf", aProgress.fractionCompleted);
            NSString *responsestring = [ NSString stringWithFormat: @"{ \"type\" : \"downloadprogress\", \"data\" : { \"progressvalue\" : \"%.20lf\" } }", aProgress.fractionCompleted ];

            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:responsestring];
            [ result setKeepCallbackAsBool:YES ];
            [ self.commandDelegate sendPluginResult:result callbackId:self.callbackcommand.callbackId ];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:totalDownloadProgressChangedNotification object:aProgress];
        }
        else
        {
            NSLog(@"ERR: Invalid keyPath (%@, %d)", [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
        }
    }
    else
    {
        [super observeValueForKeyPath:aKeyPath
                             ofObject:anObject
                               change:aChange
                              context:aContext];
    }
}


- (void)resetProgressIfNoActiveDownloadsRunning
{
    //PermanentConnection *theAppDelegate = (PermanentConnection *)[UIApplication sharedApplication].delegate;
    BOOL aHasActiveDownloadsFlag = [self.fileDownloader hasActiveDownloads];
    if (aHasActiveDownloadsFlag == NO)
    {
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            [self.progress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
        }
        self.progress = [NSProgress progressWithTotalUnitCount:0];
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
        {
            [self.progress addObserver:self
                            forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                               options:NSKeyValueObservingOptionInitial
                               context:PluginDownloadStoreProgressObserverContext];
        }
    }
}


#pragma mark - Start Download


- (void)startDownloadWithDownloadItem:(nonnull PluginDownloadItem *)aPluginDownloadItem
{
    NSLog(@"%s", "DOWNLOAD startDownloadWithDownloadItem");
    [self resetProgressIfNoActiveDownloadsRunning];
    NSLog(@"%s", "DOWNLOAD startDownloadWithDownloadItem");
    
    if ((aPluginDownloadItem.status != PluginDownloadItemStatusCancelled) && (aPluginDownloadItem.status != PluginDownloadItemStatusCompleted))
    {
        NSLog(@"%s", "DOWNLOAD status");
        //PermanentConnection *theAppDelegate = (PermanentConnection *)[UIApplication sharedApplication].delegate;
        BOOL isDownloading = [self.fileDownloader isDownloadingIdentifier:aPluginDownloadItem.downloadIdentifier];
        if (isDownloading == NO)
        {
            aPluginDownloadItem.status = PluginDownloadItemStatusStarted;
            
            [self storePluginDownloadItems];
            
            // kick off individual download
            if (aPluginDownloadItem.resumeData.length > 0)
            {
                NSLog(@"%s", "DOWNLOAD usingResumeData");
                [self.fileDownloader startDownloadWithIdentifier:aPluginDownloadItem.downloadIdentifier usingResumeData:aPluginDownloadItem.resumeData];
            }
            else
            {
                NSLog(@"%s", "DOWNLOAD aPluginDownloadItem");
                [self.fileDownloader startDownloadWithIdentifier:aPluginDownloadItem.downloadIdentifier fromRemoteURL:aPluginDownloadItem.remoteURL];
            }
        }
    }
}


- (void)resumeDownloadWithDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    [self resetProgressIfNoActiveDownloadsRunning];
    
    NSUInteger aFoundDownloadItemIndex = [self.downloadItemsArray indexOfObjectPassingTest:^BOOL(PluginDownloadItem *aPluginDownloadItem, NSUInteger anIndex, BOOL *aStopFlag) {
        if ([aPluginDownloadItem.downloadIdentifier isEqualToString:aDownloadIdentifier])
        {
            return YES;
        }
        return NO;
    }];
    if (aFoundDownloadItemIndex != NSNotFound)
    {
        PluginDownloadItem *aPluginDownloadItem = [self.downloadItemsArray objectAtIndex:aFoundDownloadItemIndex];
        if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_8_4)
        {
            if (aPluginDownloadItem.progress.nativeProgress)
            {
                [aPluginDownloadItem.progress.nativeProgress resume];
            }
            else
            {
                [self startDownloadWithDownloadItem:aPluginDownloadItem];
            }
        }
        else
        {
            [self startDownloadWithDownloadItem:aPluginDownloadItem];
        }
    }
}


#pragma mark - Cancel Download


- (void)cancelDownloadWithDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier
{
    NSUInteger aFoundDownloadItemIndex = [self.downloadItemsArray indexOfObjectPassingTest:^BOOL(PluginDownloadItem *aPluginDownloadItem, NSUInteger anIndex, BOOL *aStopFlag) {
        if ([aPluginDownloadItem.downloadIdentifier isEqualToString:aDownloadIdentifier])
        {
            return YES;
        }
        return NO;
    }];
    if (aFoundDownloadItemIndex != NSNotFound)
    {
        PluginDownloadItem *aCancelledDownloadItem = [self.downloadItemsArray objectAtIndex:aFoundDownloadItemIndex];
        aCancelledDownloadItem.status = PluginDownloadItemStatusCancelled;
        [self storePluginDownloadItems];
    }
    else
    {
        NSLog(@"ERR: Cancelled download item not found (id: %@) (%@, %d)", aDownloadIdentifier, [NSString stringWithUTF8String:__FILE__].lastPathComponent, __LINE__);
    }
}


#pragma mark - Network Activity Indicator


- (void)toggleNetworkActivityIndicatorVisible:(BOOL)visible
{
    visible ? self.networkActivityIndicatorCount++ : self.networkActivityIndicatorCount--;
    NSLog(@"INFO: NetworkActivityIndicatorCount: %@", @(self.networkActivityIndicatorCount));
    [UIApplication sharedApplication].networkActivityIndicatorVisible = (self.networkActivityIndicatorCount > 0);
}


#pragma mark - Persistence


- (void)storePluginDownloadItems
{
    NSMutableArray <NSData *> *aPluginDownloadItemsArchiveArray = [NSMutableArray arrayWithCapacity:self.downloadItemsArray.count];
    for (PluginDownloadItem *aPluginDownloadItem in self.downloadItemsArray)
    {
        NSData *aPluginDownloadItemEncoded = [NSKeyedArchiver archivedDataWithRootObject:aPluginDownloadItem];
        [aPluginDownloadItemsArchiveArray addObject:aPluginDownloadItemEncoded];
    }
    NSUserDefaults *userData = [NSUserDefaults standardUserDefaults];
    [userData setObject:aPluginDownloadItemsArchiveArray forKey:@"downloadItems"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (nonnull NSMutableArray<PluginDownloadItem *> *)restoredDownloadItems
{
    NSMutableArray <PluginDownloadItem *> *aRestoredMutableDownloadItemsArray = [NSMutableArray array];
    NSMutableArray <NSData  *> *aRestoredMutableDataItemsArray = [[[NSUserDefaults standardUserDefaults] objectForKey:@"downloadItems"] mutableCopy];
    if (aRestoredMutableDataItemsArray == nil)
    {
        aRestoredMutableDataItemsArray = [NSMutableArray array];
    }
    for (NSData *aDataItem in aRestoredMutableDataItemsArray)
    {
        PluginDownloadItem *aPluginDownloadItem = [NSKeyedUnarchiver unarchiveObjectWithData:aDataItem];
        [aRestoredMutableDownloadItemsArray addObject:aPluginDownloadItem];
    }
    return aRestoredMutableDownloadItemsArray;
}


@end