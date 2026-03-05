//
//  AvroKeyboard
//
//  Created by Rifat Nabi on 7/1/12.
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CacheManager : NSObject {
    NSMutableDictionary* _weightCache;
    NSMutableDictionary* _phoneticCache;
    NSMutableDictionary* _recentBaseCache;
}

+ (CacheManager *)sharedInstance;

- (void)persist;

// Weight Cache — remembers user's preferred candidate for a given input
- (NSString*)weightForInput:(NSString*)input;
- (void)removeWeightForInput:(NSString*)input;
- (void)setWeight:(NSString*)candidate forInput:(NSString*)input;

// Phonetic Cache — caches suggestion lists for previously seen inputs
- (NSArray*)suggestionsForInput:(NSString*)input;
- (void)setSuggestions:(NSArray*)suggestions forInput:(NSString*)input;

// Suffix Base Cache — maps suffixed candidates back to their base form
- (void)removeAllSuffixBases;
- (NSArray*)suffixBaseForCandidate:(NSString*)candidate;
- (void)setSuffixBase:(NSArray*)base forCandidate:(NSString*)candidate;

@end
