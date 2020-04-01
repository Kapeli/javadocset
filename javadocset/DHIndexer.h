#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@interface DHIndexer : NSObject <WebFrameLoadDelegate>

@property (retain) NSString *apiPath;
@property (retain) NSString *workingDir;
@property (retain) NSString *docsetName;
@property (retain) NSString *docsetPath;

@property (retain) NSString *contentsDir;
@property (retain) NSString *resourcesDir;
@property (retain) NSString *documentsDir;

@property (assign) BOOL hasMultipleIndexes;
@property (retain) NSMutableArray *toIndex;

@property (retain) WebView *webView;
@property (retain) NSMutableArray *added;
@property (retain) FMDatabase *db;

@end
