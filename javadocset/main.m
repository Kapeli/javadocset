#import <Foundation/Foundation.h>
#import "DHIndexer.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        DHIndexer *indexer = [[DHIndexer alloc] init];
        if(!indexer)
        {
            return 1;
        }
        while([[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])
        {
        }
    }
    return 0;
}

