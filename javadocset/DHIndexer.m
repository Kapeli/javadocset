#import "DHIndexer.h"

@implementation DHIndexer

- (void)startIndexing
{
    printf("Start indexing...\n");
    self.added = [NSMutableArray array];
    self.webView = [[WebView alloc] init];
    [self initDB];
    [self.webView setFrameLoadDelegate:self];
    [self step];
}

- (void)step
{
    if(!self.toIndex.count)
    {
        [self.db commit];
        [self.db close];
        printf("All done!\n");
        exit(0);
    }
    else
    {
        NSString *next = [self.toIndex objectAtIndex:0];
        printf("Indexing %s...", [[next lastPathComponent] UTF8String]);
        [self.toIndex removeObjectAtIndex:0];
        [self.webView setMainFrameURL:next];
    }
}

- (void)parseEntries
{
    DOMDocument *document = [self.webView mainFrameDocument];
    DOMNodeList *anchors = [document getElementsByTagName:@"a"];
    int count = 0;
    for(int i = 0; i < anchors.length; i++)
    {
        DOMHTMLAnchorElement *anchor = (DOMHTMLAnchorElement*)[anchors item:i];
        DOMHTMLElement *parent = (DOMHTMLElement*)[anchor parentElement];
        if([parent firstChild] != anchor)
        {
            continue;
        }
        if([[parent tagName] isCaseInsensitiveLike:@"span"] || [[parent tagName] isCaseInsensitiveLike:@"code"])
        {
            parent = (DOMHTMLElement*)[parent parentElement];
            if([parent firstChild] != [anchor parentElement])
            {
                continue;
            }
        }
        if(![[parent tagName] isCaseInsensitiveLike:@"dt"])
        {
            continue;
        }
        NSString *text = [parent innerText];
        NSString *type = nil;
        NSString *name = [anchor innerText];
        NSString *dtClassName = [parent className];
        dtClassName = (dtClassName) ? dtClassName : @"";
        if([text rangeOfString:@"Class in"].location != NSNotFound || [text rangeOfString:@"- class"].location != NSNotFound || [dtClassName hasSuffix:@"class"])
        {
            type = @"Class";
        }
        else if([text rangeOfString:@"Static method in"].location != NSNotFound || [dtClassName hasSuffix:@"method"])
        {
            type = @"Method";
        }
        else if([text rangeOfString:@"Static variable in"].location != NSNotFound || [dtClassName hasSuffix:@"field"] || [text rangeOfString:@"Field in"].location != NSNotFound)
        {
            type = @"Field";
        }
        else if([text rangeOfString:@"Constructor"].location != NSNotFound || [dtClassName hasSuffix:@"constructor"])
        {
            type = @"Constructor";
        }
        else if([text rangeOfString:@"Method in"].location != NSNotFound)
        {
            type = @"Method";
        }
        else if([text rangeOfString:@"Variable in"].location != NSNotFound)
        {
            type = @"Field";
        }
        else if([text rangeOfString:@"Interface in"].location != NSNotFound || [text rangeOfString:@"- interface"].location != NSNotFound || [dtClassName hasSuffix:@"interface"])
        {
            type = @"Interface";
        }
        else if([text rangeOfString:@"Exception in"].location != NSNotFound || [text rangeOfString:@"- exception"].location != NSNotFound || [dtClassName hasSuffix:@"exception"])
        {
            type = @"Exception";
        }
        else if([text rangeOfString:@"Error in"].location != NSNotFound || [text rangeOfString:@"- error"].location != NSNotFound || [dtClassName hasSuffix:@"error"])
        {
            type = @"Error";
        }
        else if([text rangeOfString:@"Enum in"].location != NSNotFound || [text rangeOfString:@"- enum"].location != NSNotFound || [dtClassName hasSuffix:@"enum"])
        {
            type = @"Enum";
        }
        else if([text rangeOfString:@"package"].location != NSNotFound || [dtClassName hasSuffix:@"package"])
        {
            type = @"Package";
        }
        else if([text rangeOfString:@"Annotation Type"].location != NSNotFound || [dtClassName hasSuffix:@"annotation"])
        {
            type = @"Notation";
        }
        else
        {
            printf("\nWarning: could not determine type for %s. Please tell the developer about this!\n", [name UTF8String]);
            printf("\n%s and %s\n", [text UTF8String], [dtClassName UTF8String]);
            continue;
        }
        NSString *path = [[anchor absoluteLinkURL] absoluteString];
        NSRange baseRange = [path rangeOfString:@".docset/Contents/Resources/Documents/" options:NSBackwardsSearch];
        if(baseRange.location != NSNotFound)
        {
            path = [path substringFromIndex:baseRange.location+baseRange.length];
            [self insertName:name type:type path:path];
        }
        ++count;
    }
    printf("added %d entries\n", count);
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    printf("failed to load page\n");
    [self step];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if(frame == [self.webView mainFrame])
    {
        [self parseEntries];
        [self step];        
    }
}

- (void)insertName:(NSString *)name type:(NSString *)type path:(NSString *)path
{
    if(name.length > 200)
    {
        // there's a bug in SQLite which causes it to sometimes hang on entries with > 200 chars
        name = [name substringToIndex:200];
    }
    NSString *parsedPath = path;
    if([parsedPath rangeOfString:@"#"].location != NSNotFound)
    {
        parsedPath = [parsedPath substringToIndex:[parsedPath rangeOfString:@"#"].location];
    }
//    NSString *fullPath = [self.documentsDir stringByAppendingPathComponent:parsedPath];
//    BOOL isDir = NO;
//    if(![[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir])
//    {
//        printf("Warning: did not add %s of type %s at path %s. Reason: file does not exist\n", [name UTF8String], [type UTF8String], [path UTF8String]);
//        return;
//    }
//    if(isDir)
//    {
//        printf("Warning: did not add %s of type %s at path %s. Reason: path is a folder\n", [name UTF8String], [type UTF8String], [path UTF8String]);
//        return;
//    }
    NSString *add = [NSString stringWithFormat:@"%@%@%@", name, type, parsedPath];
    if(![self.added containsObject:add])
    {
        [self.added addObject:add];
        [self.db executeUpdate:@"INSERT INTO searchIndex(name, type, path) VALUES (?, ?, ?)", name, type, path];
    }
}

- (void)initDB
{
    self.db = [FMDatabase databaseWithPath:[self dbPath]];
    [self.db open];
    [self.db beginDeferredTransaction];
    [self.db executeUpdate:@"CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT)"];
}

- (NSString *)dbPath
{
    return [self.resourcesDir stringByAppendingPathComponent:@"docSet.dsidx"];
}

- (id)init
{
    self = [super init];
    if(self)
    {
        NSArray *arguments = [[NSProcessInfo processInfo] arguments];
        if(arguments.count == 2 && [[arguments objectAtIndex:1] isEqualToString:@"--help"])
        {
            [self printUsage];
            exit(0);
        }
        if(arguments.count != 3)
        {
            printf("Error: too %s arguments\n", (arguments.count > 3) ? "many" : "few");
            [self printUsage];
            return nil;
        }
        setbuf(stdout, NULL);
        printf("Creating docset structure...");
        NSString *name = [arguments objectAtIndex:1];
        NSString *path = [arguments objectAtIndex:2];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        self.workingDir = [fileManager currentDirectoryPath];
        if(![path hasPrefix:@"/"])
        {
            path = [self.workingDir stringByAppendingPathComponent:path];
        }
        path = [path stringByStandardizingPath];
        self.apiPath = path;
        self.docsetName = name;
        self.docsetPath = [self.workingDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.docset", name]];
        self.contentsDir = [self.docsetPath stringByAppendingPathComponent:@"Contents"];
        self.resourcesDir = [self.contentsDir stringByAppendingPathComponent:@"Resources"];
        self.documentsDir = [self.resourcesDir stringByAppendingPathComponent:@"Documents"];
        if([fileManager fileExistsAtPath:self.docsetPath])
        {
            [fileManager removeItemAtPath:self.docsetPath error:nil];
        }
        NSError *error = nil;
        if(![fileManager createDirectoryAtPath:self.documentsDir withIntermediateDirectories:YES attributes:nil error:&error])
        {
            printf("\nError: could not create docset directory structure \"%s\"\n", [self.documentsDir UTF8String]);
            printf("File manager error was %s\n", [[error localizedDescription] UTF8String]);
            return nil;
        }
        NSString *docsetIndexFile = nil;
        NSString *summaryPath = [self.apiPath stringByAppendingPathComponent:@"overview-summary.html"];
        BOOL foundSummary = NO;
        if(![fileManager fileExistsAtPath:summaryPath])
        {
            NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath:self.apiPath];
            NSInteger count = 0;
            NSString *file = nil;
            while((file = [dirEnum nextObject]) && count < 10000)
            {
                if([file isEqualToString:@"overview-summary.html"])
                {
                    self.apiPath = [[self.apiPath stringByAppendingPathComponent:file] stringByDeletingLastPathComponent];
                    foundSummary = YES;
                }
                ++count;
            }
        }
        else
        {
            foundSummary = YES;
        }
        if(foundSummary)
        {
            docsetIndexFile = @"overview-summary.html";
        }
        if([fileManager fileExistsAtPath:[self.apiPath stringByAppendingPathComponent:@"index-files"]])
        {
            docsetIndexFile = (docsetIndexFile) ? docsetIndexFile : @"index-files/index-1.html";
            self.hasMultipleIndexes = YES;
        }
        printf("done\n");
        [self copyFiles];
        self.toIndex = [NSMutableArray array];
        if(!self.hasMultipleIndexes && [fileManager fileExistsAtPath:[self.documentsDir stringByAppendingPathComponent:@"index-all.html"]])
        {
            [self.toIndex addObject:[self.documentsDir stringByAppendingPathComponent:@"index-all.html"]];
            docsetIndexFile = (docsetIndexFile) ? docsetIndexFile : @"index-all.html";
        }
        else
        {
            NSString *indexFilesPath = [self.documentsDir stringByAppendingPathComponent:@"index-files"];
            NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath:indexFilesPath];
            NSString *indexFile = nil;
            while(indexFile = [dirEnum nextObject])
            {
                if([indexFile hasPrefix:@"index-"] && [indexFile hasSuffix:@".html"])
                {
                    [self.toIndex addObject:[indexFilesPath stringByAppendingPathComponent:indexFile]];
                }
            }
        }
        if(!self.toIndex.count)
        {
            printf("\nError: The API folder you specified does not contain any index files (either a index-all.html file or a index-files folder) and is not valid. Please contact the developer if you receive this error by mistake.\n\n");
            [self printUsage];
            return nil;
        }
        [self writeInfoPlist:docsetIndexFile];
        [self startIndexing];
    }
    return self;
}

- (void)writeInfoPlist:(NSString *)docsetIndexFile
{
    NSString *platform = [[[self.docsetName componentsSeparatedByString:@" "] objectAtIndex:0] lowercaseString];
    [[NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>%@</string><key>CFBundleName</key><string>%@</string><key>DocSetPlatformFamily</key><string>%@</string><key>dashIndexFilePath</key><string>%@</string><key>DashDocSetFamily</key><string>java</string><key>isDashDocset</key><true/></dict></plist>", platform, self.docsetName, platform, docsetIndexFile] writeToFile:[self.contentsDir stringByAppendingPathComponent:@"Info.plist"] atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

- (void)copyFiles
{
    printf("Copying files...");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath:self.apiPath];
    NSString *file = nil;
    while(file = [dirEnum nextObject])
    {
        BOOL isDir = NO;
        NSString *fullPath = [self.apiPath stringByAppendingPathComponent:file];
        if([fileManager fileExistsAtPath:fullPath isDirectory:&isDir])
        {
            if(isDir)
            {
                [dirEnum skipDescendants];
            }
            NSError *error = nil;
            if(![fileManager copyItemAtPath:fullPath toPath:[self.documentsDir stringByAppendingPathComponent:file] error:&error])
            {
                printf("\nCould not copy %s, error message: %s\n", [file UTF8String], [[error localizedDescription] UTF8String]);
            }
        }
    }
    printf("done\n");
}

- (void)printUsage
{
    printf("Usage: javadocset <docset name> <javadoc API folder>\n<docset name> - anything you want\n<javadoc API folder> - the path of the javadoc API folder you want to index\n");
}

@end
