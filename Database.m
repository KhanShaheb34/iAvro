//
//  AvroKeyboard
//
//  Created by Rifat Nabi on 6/28/12.
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

#import "Database.h"
#import "RegexParser.h"
#import <sqlite3.h>

#ifdef DEBUG
static BOOL DatabasePerfLoggingEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"EnablePerfLog"];
}

static double DatabasePerfNowMs(void) {
    return CFAbsoluteTimeGetCurrent() * 1000.0;
}

#define DATABASE_PERF_LOG(fmt, ...) NSLog((@"[AvroPerf] " fmt), ##__VA_ARGS__)
#endif

static BOOL DatabaseRegexBodyIsLiteral(NSString *pattern) {
    if (!pattern || [pattern length] == 0) {
        return NO;
    }
    static NSCharacterSet *metaCharacters = nil;
    if (!metaCharacters) {
        metaCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"\\.^$*+?()[]{}|"] retain];
    }
    return [pattern rangeOfCharacterFromSet:metaCharacters].location == NSNotFound;
}

static Database* sharedInstance = nil;

@implementation Database

+ (Database *)sharedInstance  {
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
        _db = [[NSMutableDictionary alloc] initWithCapacity:0];
        _dbLookup = [[NSMutableDictionary alloc] initWithCapacity:0];
        _findCache = [[NSCache alloc] init];
        [_findCache setCountLimit:1024];
        _suffix = [[NSMutableDictionary alloc] initWithCapacity:0];
        
        NSAutoreleasePool *loopPool = [[NSAutoreleasePool alloc] init];
        
        NSString* filePath = [[NSBundle mainBundle] pathForResource:@"database" ofType:@"db3"];
        sqlite3 *sqliteDb = NULL;
        int rc = sqlite3_open_v2([filePath fileSystemRepresentation], &sqliteDb, SQLITE_OPEN_READONLY, NULL);
        if (rc != SQLITE_OK || !sqliteDb) {
            if (sqliteDb) {
                sqlite3_close(sqliteDb);
            }
            @throw [NSException exceptionWithName:@"Database init"
                                           reason:@"Unable to open database.db3"
                                         userInfo:nil];
        }
        
        [self loadTableWithName:@"A" fromDatabase:sqliteDb];
        [self loadTableWithName:@"AA" fromDatabase:sqliteDb];
        [self loadTableWithName:@"B" fromDatabase:sqliteDb];
        [self loadTableWithName:@"BH" fromDatabase:sqliteDb];
        [self loadTableWithName:@"C" fromDatabase:sqliteDb];
        [self loadTableWithName:@"CH" fromDatabase:sqliteDb];
        [self loadTableWithName:@"D" fromDatabase:sqliteDb];
        [self loadTableWithName:@"Dd" fromDatabase:sqliteDb];
        [self loadTableWithName:@"Ddh" fromDatabase:sqliteDb];
        [self loadTableWithName:@"Dh" fromDatabase:sqliteDb];
        [self loadTableWithName:@"E" fromDatabase:sqliteDb];
        [self loadTableWithName:@"G" fromDatabase:sqliteDb];
        [self loadTableWithName:@"Gh" fromDatabase:sqliteDb];
        [self loadTableWithName:@"H" fromDatabase:sqliteDb];
        [self loadTableWithName:@"I" fromDatabase:sqliteDb];
        [self loadTableWithName:@"II" fromDatabase:sqliteDb];
        [self loadTableWithName:@"J" fromDatabase:sqliteDb];
        [self loadTableWithName:@"JH" fromDatabase:sqliteDb];
        [self loadTableWithName:@"K" fromDatabase:sqliteDb];
        [self loadTableWithName:@"KH" fromDatabase:sqliteDb];
        [self loadTableWithName:@"Khandatta" fromDatabase:sqliteDb];
        [self loadTableWithName:@"L" fromDatabase:sqliteDb];
        [self loadTableWithName:@"M" fromDatabase:sqliteDb];
        [self loadTableWithName:@"N" fromDatabase:sqliteDb];
        [self loadTableWithName:@"NGA" fromDatabase:sqliteDb];
        [self loadTableWithName:@"NN" fromDatabase:sqliteDb];
        [self loadTableWithName:@"NYA" fromDatabase:sqliteDb];
        [self loadTableWithName:@"O" fromDatabase:sqliteDb];
        [self loadTableWithName:@"OI" fromDatabase:sqliteDb];
        [self loadTableWithName:@"OU" fromDatabase:sqliteDb];
        [self loadTableWithName:@"P" fromDatabase:sqliteDb];
        [self loadTableWithName:@"PH" fromDatabase:sqliteDb];
        [self loadTableWithName:@"R" fromDatabase:sqliteDb];
        [self loadTableWithName:@"RR" fromDatabase:sqliteDb];
        [self loadTableWithName:@"RRH" fromDatabase:sqliteDb];
        [self loadTableWithName:@"RRI" fromDatabase:sqliteDb];
        [self loadTableWithName:@"S" fromDatabase:sqliteDb];
        [self loadTableWithName:@"SH" fromDatabase:sqliteDb];
        [self loadTableWithName:@"SS" fromDatabase:sqliteDb];
        [self loadTableWithName:@"T" fromDatabase:sqliteDb];
        [self loadTableWithName:@"TH" fromDatabase:sqliteDb];
        [self loadTableWithName:@"TT" fromDatabase:sqliteDb];
        [self loadTableWithName:@"TTH" fromDatabase:sqliteDb];
        [self loadTableWithName:@"U" fromDatabase:sqliteDb];
        [self loadTableWithName:@"UU" fromDatabase:sqliteDb];
        [self loadTableWithName:@"Y" fromDatabase:sqliteDb];
        [self loadTableWithName:@"Z" fromDatabase:sqliteDb];
        
        [self loadSuffixTableFromDatabase:sqliteDb];
        
        sqlite3_close(sqliteDb);
        
        [loopPool release];
    }
    return self;
}

- (void)dealloc {
    [_db release];
    [_dbLookup release];
    [_findCache release];
    [_suffix release];
    [super dealloc];
}

- (void)loadTableWithName:(NSString*)name fromDatabase:(sqlite3*)sqliteDb {
    NSMutableArray* items = [[NSMutableArray alloc] init];

    NSString *query = [NSString stringWithFormat:@"SELECT Words FROM \"%@\"", name];
    sqlite3_stmt *statement = NULL;
    int prepare = sqlite3_prepare_v2(sqliteDb, [query UTF8String], -1, &statement, NULL);
    if (prepare == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            const unsigned char *word = sqlite3_column_text(statement, 0);
            if (word) {
                [items addObject:[NSString stringWithUTF8String:(const char *)word]];
            }
        }
    }
    sqlite3_finalize(statement);
    
    /*
     NSLog(@"-----------------------------------------------------------------");
     NSLog(@"%d items added to key %@", count, name);
     NSLog(@"-----------------------------------------------------------------");
     */
    
    [_db setObject:items forKey:[name lowercaseString]];
    [_dbLookup setObject:[NSSet setWithArray:items] forKey:[name lowercaseString]];
    [items release];
}

- (void)loadSuffixTableFromDatabase:(sqlite3*)sqliteDb {
    const char *query = "SELECT English, Bangla FROM Suffix";
    sqlite3_stmt *statement = NULL;
    int prepare = sqlite3_prepare_v2(sqliteDb, query, -1, &statement, NULL);
    if (prepare == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            const unsigned char *english = sqlite3_column_text(statement, 0);
            const unsigned char *bangla = sqlite3_column_text(statement, 1);
            if (english && bangla) {
                NSString *englishString = [NSString stringWithUTF8String:(const char *)english];
                NSString *banglaString = [NSString stringWithUTF8String:(const char *)bangla];
                [_suffix setObject:banglaString forKey:englishString];
            }
        }
    }
    sqlite3_finalize(statement);
}

- (NSArray*)find:(NSString*)term {
#ifdef DEBUG
    double perfStartMs = DatabasePerfNowMs();
    double perfRegexMs = 0.0;
    double perfScanMs = 0.0;
    NSUInteger perfTableCount = 0;
    NSUInteger perfScannedCount = 0;
    NSUInteger perfMatchedCount = 0;
    BOOL perfCacheHit = NO;
    BOOL perfLiteralPath = NO;
#endif
    if (!term || [term length] == 0) {
        return [NSArray array];
    }
    
    NSArray *cachedResult = [_findCache objectForKey:term];
    if (cachedResult) {
#ifdef DEBUG
        perfCacheHit = YES;
        if (DatabasePerfLoggingEnabled()) {
            double totalMs = DatabasePerfNowMs() - perfStartMs;
            DATABASE_PERF_LOG(@"database.find total=%.2fms cache=hit term='%@' result=%lu",
                              totalMs,
                              term,
                              (unsigned long)[cachedResult count]);
        }
#endif
        return cachedResult;
    }
    
    // Left Most Character
    unichar lmc = [[term lowercaseString] characterAtIndex:0];
#ifdef DEBUG
    double regexStartMs = DatabasePerfNowMs();
#endif
    NSString *regexBody = [[RegexParser sharedInstance] parse:term];
    BOOL useLiteralPath = DatabaseRegexBodyIsLiteral(regexBody);
#ifdef DEBUG
    perfLiteralPath = useLiteralPath;
#endif
    NSRegularExpression *compiledRegex = nil;
    if (!useLiteralPath) {
        NSString* regex = [NSString stringWithFormat:@"^%@$", regexBody];
        NSError *regexError = nil;
        compiledRegex = [NSRegularExpression regularExpressionWithPattern:regex
                                                                  options:0
                                                                    error:&regexError];
        if (regexError || !compiledRegex) {
            return [NSArray array];
        }
    }
#ifdef DEBUG
    perfRegexMs = DatabasePerfNowMs() - regexStartMs;
#endif
    NSMutableArray* tableList = [[NSMutableArray alloc] initWithCapacity:0];
    NSMutableSet* suggestions = [[NSMutableSet alloc] initWithCapacity:0];
    
    switch (lmc) {
        case 'a':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"a", @"aa", @"e", @"oi", @"o", @"nya", @"y", nil]];
            break;
        case 'b':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"b", @"bh", nil]];
            break;
        case 'c':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"c", @"ch", @"k", nil]];
            break;
        case 'd':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"d", @"dh", @"dd", @"ddh", nil]];
            break;
        case 'e':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"i", @"ii", @"e", @"y", nil]];
            break;
        case 'f':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"ph", nil]];
            break;
        case 'g':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"g", @"gh", @"j", nil]];
            break;
        case 'h':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"h", nil]];
            break;
        case 'i':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"i", @"ii", @"y", nil]];
            break;
        case 'j':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"j", @"jh", @"z", nil]];
            break;
        case 'k':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"k", @"kh", nil]];
            break;
        case 'l':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"l", nil]];
            break;
        case 'm':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"h", @"m", nil]];
            break;
        case 'n':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"n", @"nya", @"nga", @"nn", nil]];
            break;
        case 'o':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"a", @"u", @"uu", @"oi", @"o", @"ou", @"y", nil]];
            break;
        case 'p':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"p", @"ph", nil]];
            break;
        case 'q':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"k", nil]];
            break;
        case 'r':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"rri", @"h", @"r", @"rr", @"rrh", nil]];
            break;
        case 's':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"s", @"sh", @"ss", nil]];
            break;
        case 't':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"t", @"th", @"tt", @"tth", @"khandatta", nil]];
            break;
        case 'u':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"u", @"uu", @"y", nil]];
            break;
        case 'v':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"bh", nil]];
            break;
        case 'w':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"o", nil]];
            break;
        case 'x':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"e", @"k", nil]];
            break;
        case 'y':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"i", @"y", nil]];
            break;
        case 'z':
            [tableList addObjectsFromArray:
             [NSArray arrayWithObjects:@"h", @"j", @"jh", @"z", nil]];
            break;
        default:
            break;
    }
#ifdef DEBUG
    perfTableCount = [tableList count];
    double scanStartMs = DatabasePerfNowMs();
#endif
    
    for (NSString* table in tableList) {
        if (useLiteralPath) {
            NSSet *lookup = [_dbLookup objectForKey:table];
#ifdef DEBUG
            perfScannedCount += [lookup count];
#endif
            if ([lookup containsObject:regexBody]) {
                [suggestions addObject:regexBody];
#ifdef DEBUG
                ++perfMatchedCount;
#endif
            }
        } else {
            NSArray* tableData = [_db objectForKey:table];
            for (NSString* tmpString in tableData) {
#ifdef DEBUG
                ++perfScannedCount;
#endif
                NSRange searchRange = NSMakeRange(0, [tmpString length]);
                if ([compiledRegex firstMatchInString:tmpString options:0 range:searchRange]) {
                    [suggestions addObject:tmpString];
#ifdef DEBUG
                    ++perfMatchedCount;
#endif
                }
            }
        }
    }
#ifdef DEBUG
    perfScanMs = DatabasePerfNowMs() - scanStartMs;
#endif
    
    NSArray *result = [suggestions allObjects];
    [_findCache setObject:result forKey:term];
    
    [tableList release];
    [suggestions autorelease];

#ifdef DEBUG
    if (DatabasePerfLoggingEnabled()) {
        double totalMs = DatabasePerfNowMs() - perfStartMs;
        if (totalMs >= 1.0) {
            DATABASE_PERF_LOG(@"database.find total=%.2fms regex=%.2fms scan=%.2fms cache=%@ literal=%@ term='%@' tables=%lu scanned=%lu matched=%lu",
                              totalMs,
                              perfRegexMs,
                              perfScanMs,
                              perfCacheHit ? @"hit" : @"miss",
                              perfLiteralPath ? @"yes" : @"no",
                              term,
                              (unsigned long)perfTableCount,
                              (unsigned long)perfScannedCount,
                              (unsigned long)perfMatchedCount);
        }
    }
#endif
    
    return result;
}

- (NSString*)banglaForSuffix:(NSString*)suffix {
    return [_suffix objectForKey:suffix];
}

@end
