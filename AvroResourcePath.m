//
//  AvroKeyboard
//
//  Shared resource-path resolution for data files.
//

#import "AvroResourcePath.h"
#include <stdlib.h>

NSString *AvroResourcePathForFile(NSString *name, NSString *ext, Class bundleClass) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *fileName = [NSString stringWithFormat:@"%@.%@", name, ext];

    const char *resourceDir = getenv("IAVRO_RESOURCE_DIR");
    if (resourceDir) {
        NSString *path = [[NSString stringWithUTF8String:resourceDir] stringByAppendingPathComponent:fileName];
        if ([fileManager fileExistsAtPath:path]) {
            return path;
        }
    }

    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:ext];
    if (path && [fileManager fileExistsAtPath:path]) {
        return path;
    }

    if (bundleClass) {
        path = [[NSBundle bundleForClass:bundleClass] pathForResource:name ofType:ext];
        if (path && [fileManager fileExistsAtPath:path]) {
            return path;
        }
    }

    path = [[[fileManager currentDirectoryPath] stringByAppendingPathComponent:name] stringByAppendingPathExtension:ext];
    if ([fileManager fileExistsAtPath:path]) {
        return path;
    }

    return nil;
}
