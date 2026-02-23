//
//  AvroKeyboard
//
//  Created by Rifat Nabi on 6/28/12.
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

#import "Suggestion.h"
#import "AvroParser.h"
#import "AutoCorrect.h"
#import "RegexParser.h"
#import "Database.h"
#import "NSString+Levenshtein.h"
#import "CacheManager.h"

#ifdef DEBUG
static BOOL SuggestionPerfLoggingEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"EnablePerfLog"];
}

static double SuggestionPerfNowMs(void) {
    return CFAbsoluteTimeGetCurrent() * 1000.0;
}

#define SUGGESTION_PERF_LOG(fmt, ...) NSLog((@"[AvroPerf] " fmt), ##__VA_ARGS__)
#endif

static Suggestion* sharedInstance = nil;

@implementation Suggestion

+ (Suggestion *)sharedInstance  {
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
        _suggestions = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return self;
}

- (void)dealloc {
    [_suggestions release];
    [super dealloc];
}

- (NSMutableArray*)getList:(NSString*)term {
#ifdef DEBUG
    double perfStartMs = SuggestionPerfNowMs();
    double perfParseMs = 0.0;
    double perfCacheMs = 0.0;
    double perfDictionaryMs = 0.0;
    double perfSuffixMs = 0.0;
#endif
    if (term && [term length] == 0) {
        return _suggestions;
    }
    
    // Suggestions from Default Parser
#ifdef DEBUG
    double parseStartMs = SuggestionPerfNowMs();
#endif
    NSString* paresedString = [[AvroParser sharedInstance] parse:term];
#ifdef DEBUG
    perfParseMs = SuggestionPerfNowMs() - parseStartMs;
#endif
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"IncludeDictionary"]) {
        // Saving humanity by reducing a few CPU cycles
#ifdef DEBUG
        double cacheStartMs = SuggestionPerfNowMs();
#endif
        [_suggestions addObjectsFromArray:[[CacheManager sharedInstance] arrayForKey:term]];
#ifdef DEBUG
        perfCacheMs = SuggestionPerfNowMs() - cacheStartMs;
#endif
        if (_suggestions && [_suggestions count] == 0) {
#ifdef DEBUG
            double dictionaryStartMs = SuggestionPerfNowMs();
#endif
            // Suggestions form AutoCorrect
            NSString* autoCorrect = [[AutoCorrect sharedInstance] find:term];
            if (autoCorrect) {
                [_suggestions addObject:autoCorrect];
            }
            
            // Suggestions from Dictionary
            NSArray* dicList = [[Database sharedInstance] find:term];
            if (dicList) {
                // Remove autoCorrect if it is already in the dictionary
                // PROPOSAL: don't add the autoCorrect, which matches with the dictionary entry
                if (autoCorrect && [dicList containsObject:autoCorrect]) {
                    [_suggestions removeObjectIdenticalTo:autoCorrect];
                }
                // Precompute distance once per candidate to avoid repeated work during sort.
                NSMutableDictionary *distanceByCandidate = [NSMutableDictionary dictionaryWithCapacity:[dicList count]];
                for (NSString *candidate in dicList) {
                    int distance = [paresedString computeLevenshteinDistanceWithString:candidate];
                    [distanceByCandidate setObject:[NSNumber numberWithInt:distance] forKey:candidate];
                }
                // Sort dicList based on edit distance
                NSArray* sortedDicList = [dicList sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
                    int dist1 = [[distanceByCandidate objectForKey:left] intValue];
                    int dist2 = [[distanceByCandidate objectForKey:right] intValue];
                    if (dist1 < dist2) {
                        return NSOrderedAscending;
                    }
                    else if (dist1 > dist2) {
                        return NSOrderedDescending;
                    } else {
                        return NSOrderedSame;
                    }
                }];
                [_suggestions addObjectsFromArray:sortedDicList];
            }
            
            [[CacheManager sharedInstance] setArray:[[_suggestions copy] autorelease] forKey:term];
#ifdef DEBUG
            perfDictionaryMs = SuggestionPerfNowMs() - dictionaryStartMs;
#endif
        }
        
        // Suggestions with Suffix
        NSInteger i;
        BOOL alreadySelected = FALSE;
        [[CacheManager sharedInstance] removeAllBase];
#ifdef DEBUG
        double suffixStartMs = SuggestionPerfNowMs();
#endif
        for (i = [term length]-1; i > 0; --i) {
            NSString* suffix = [[Database sharedInstance] banglaForSuffix:[[term substringFromIndex:i] lowercaseString]];
            if (suffix) {
                NSString* base = [term substringToIndex:i];
                NSArray* cached = [[CacheManager sharedInstance] arrayForKey:base];
                NSString* selected;
                if (!alreadySelected) {
                    // Base user selection
                    selected = [[CacheManager sharedInstance] stringForKey:base];
                }
                // This should always exist, so it's just a safety check
                if (cached) {
                    for (NSString *item in cached) {
                        // Skip AutoCorrect English Entry
                        if ([base isEqualToString:item]) {
                            continue;
                        }
                        NSString* word;
                        // Again saving humanity cause I'm Superman, no I'm not drunk or on weed :D 
                        NSInteger cutPos = [item length] - 1;
                        
                        NSString* itemRMC = [item substringFromIndex:cutPos];   // RMC is Right Most Character
                        NSString* suffixLMC = [suffix substringToIndex:1];      // LMC is Left Most Character
                        // BEGIN :: This part was taken from http://d.pr/zTmF
                        if ([self isVowel:itemRMC] && [self isKar:suffixLMC]) {
                            word = [NSString stringWithFormat:@"%@\u09df%@", item ,suffix];
                        }
                        else {
                            if ([itemRMC isEqualToString:@"\u09ce"]) {
                                word = [NSString stringWithFormat:@"%@\u09a4%@", [item substringToIndex:cutPos], suffix];
                            }
                            else if ([itemRMC isEqualToString:@"\u0982"]) {
                                word = [NSString stringWithFormat:@"%@\u0999%@", [item substringToIndex:cutPos], suffix];
                            } else {
                                word = [NSString stringWithFormat:@"%@%@", item, suffix];
                            }
                        }
                        // END
                        
                        // Reverse Suffix Caching 
                        [[CacheManager sharedInstance] setBase:[NSArray arrayWithObjects:base, item, nil] forKey:word];
                        
                        // Check that the WORD is not already in the list
                        if (![_suggestions containsObject:word]) {
                            // Intelligent Selection
                            if (!alreadySelected && selected && [item isEqualToString:selected]) {
                                if (![[CacheManager sharedInstance] stringForKey:term]) {
                                    [[CacheManager sharedInstance] setString:word forKey:term];
                                }
                                alreadySelected = TRUE;
                            }
                            [_suggestions addObject:word];
                        }
                    }
                }
            }
        }
#ifdef DEBUG
        perfSuffixMs = SuggestionPerfNowMs() - suffixStartMs;
#endif
    }
    
    if ([_suggestions containsObject:paresedString] == NO) {
        [_suggestions addObject:paresedString];
    }

#ifdef DEBUG
    if (SuggestionPerfLoggingEnabled()) {
        double totalMs = SuggestionPerfNowMs() - perfStartMs;
        if (totalMs >= 1.0) {
            SUGGESTION_PERF_LOG(@"suggestions total=%.2fms parse=%.2fms cache=%.2fms dictionary=%.2fms suffix=%.2fms term='%@' count=%lu",
                                totalMs,
                                perfParseMs,
                                perfCacheMs,
                                perfDictionaryMs,
                                perfSuffixMs,
                                term,
                                (unsigned long)[_suggestions count]);
        }
    }
#endif
    
    return _suggestions;
}

- (BOOL)isKar:(NSString*)letter {
    return [letter isMatchedByRegex:@"^[\u09be\u09bf\u09c0\u09c1\u09c2\u09c3\u09c7\u09c8\u09cb\u09cc\u09c4]$"];
}

- (BOOL)isVowel:(NSString*)letter {
    return [letter isMatchedByRegex:@"^[\u0985\u0986\u0987\u0988\u0989\u098a\u098b\u098f\u0990\u0993\u0994\u098c\u09e1\u09be\u09bf\u09c0\u09c1\u09c2\u09c3\u09c7\u09c8\u09cb\u09cc]$"];
}

@end
