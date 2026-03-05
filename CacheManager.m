//
//  AvroKeyboard
//
//  Created by Rifat Nabi on 7/1/12.
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

#import "CacheManager.h"

static CacheManager* sharedInstance = nil;

@implementation CacheManager

+ (CacheManager *)sharedInstance  {
    if (sharedInstance == nil) {
        [[self alloc] init]; // assignment not done here, see allocWithZone
    }
	return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    
    if (sharedInstance == nil) {
        sharedInstance = [super allocWithZone:zone];
        return sharedInstance;  // assignment and return on first allocation
    }
    return nil; //on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)retain {
    return self;
}

- (oneway void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

- (NSUInteger)retainCount {
    return NSUIntegerMax;  // This is sooo not zero
}

- (id)init {
    self = [super init];
    if (self) {
        // Weight PLIST File
        NSString *path = [self getSharedFolder];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:path] == NO) {
            NSError* error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                @throw error;
            }
        }
        
        path = [path stringByAppendingPathComponent:@"weight.plist"];
        
        if ([fileManager fileExistsAtPath:path]) {
            _weightCache = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
        } else {
            _weightCache = [[NSMutableDictionary alloc] initWithCapacity:0];
        }
        _phoneticCache = [[NSMutableDictionary alloc] initWithCapacity:0];
        _recentBaseCache = [[NSMutableDictionary alloc] initWithCapacity:0];
    }
    return self;
}

- (void)dealloc {
    [self persist];
    [_phoneticCache release];
    [_recentBaseCache release];
    [_weightCache release];
    [super dealloc];
}

- (void)persist {
    [_weightCache writeToFile:[[self getSharedFolder] stringByAppendingPathComponent:@"weight.plist"] atomically:YES];
}

- (NSString*)getSharedFolder {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    return [[[paths objectAtIndex:0] 
             stringByAppendingPathComponent:@"OmicronLab"] 
            stringByAppendingPathComponent:@"Avro Keyboard"];
}

// Weight Cache
- (NSString*)weightForInput:(NSString*)input {
    return [_weightCache objectForKey:input];
}

- (void)removeWeightForInput:(NSString*)input {
    [_weightCache removeObjectForKey:input];
}

- (void)setWeight:(NSString*)candidate forInput:(NSString*)input {
    [_weightCache setObject:candidate forKey:input];
}

// Phonetic Cache
- (NSArray*)suggestionsForInput:(NSString*)input {
    return [_phoneticCache objectForKey:input];
}

- (void)setSuggestions:(NSArray*)suggestions forInput:(NSString*)input {
    [_phoneticCache setObject:suggestions forKey:input];
}

// Suffix Base Cache
- (void)removeAllSuffixBases {
    [_recentBaseCache removeAllObjects];
}

- (NSArray*)suffixBaseForCandidate:(NSString*)candidate {
    return [_recentBaseCache objectForKey:candidate];
}

- (void)setSuffixBase:(NSArray*)base forCandidate:(NSString*)candidate {
    [_recentBaseCache setObject:base forKey:candidate];
}

@end
