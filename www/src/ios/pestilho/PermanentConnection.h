#import <Cordova/CDVPlugin.h>
#import <UIKit/UIKit.h>

#import "HWIFileDownloader.h"
#import "HWIFileDownloadProgress.h"
#import "HWIFileDownloadItem.h"
#import "HWIFileDownloadDelegate.h"
#import "HWIBackgroundSessionCompletionHandlerBlock.h"

#import "PluginDownloadItem.h"

//@class PluginDownloadStore;
@class HWIFileDownloader;

@interface PermanentConnection : CDVPlugin {}

@property (nullable, nonatomic, strong) UIWindow *window;
@property (nonnull, nonatomic, strong, readonly) HWIFileDownloader *fileDownloader;
@property (nonatomic, strong, readonly, nonnull) NSMutableArray<PluginDownloadItem *> *downloadItemsArray;


// The hooks for our plugin commands
- (void)startdownload:(CDVInvokedUrlCommand *)command;
- (void)pausedownload:(CDVInvokedUrlCommand *)command;
- (void)stopdownload:(CDVInvokedUrlCommand *)command;
- (void)stopalldownload:(CDVInvokedUrlCommand *)command;
- (void)resumedownload:(CDVInvokedUrlCommand *)command;
- (void)resumealldownload:(CDVInvokedUrlCommand *)command;

- (void)startDownloadWithDownloadItem:(nonnull PluginDownloadItem *)aPluginDownloadItem;
- (void)cancelDownloadWithDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier;
- (void)resumeDownloadWithDownloadIdentifier:(nonnull NSString *)aDownloadIdentifier;

@end