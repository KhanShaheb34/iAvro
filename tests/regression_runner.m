#import <Foundation/Foundation.h>
#include <stdlib.h>

#import "AvroParser.h"
#import "Database.h"
#import "Suggestion.h"

static NSUInteger gFailures = 0;

static void Report(BOOL condition, NSString *message) {
    if (condition) {
        fprintf(stdout, "PASS %s\n", [message UTF8String]);
    } else {
        fprintf(stderr, "FAIL %s\n", [message UTF8String]);
        ++gFailures;
    }
}

static NSDictionary *LoadFixtures(NSString *path) {
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&error];
    if (!data) {
        fprintf(stderr, "Unable to read fixtures at %s: %s\n", [path UTF8String], [[error localizedDescription] UTF8String]);
        return nil;
    }

    NSDictionary *fixtures = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!fixtures) {
        fprintf(stderr, "Invalid fixture JSON %s: %s\n", [path UTF8String], [[error localizedDescription] UTF8String]);
        return nil;
    }

    return fixtures;
}

static void RunParserCases(NSArray *cases) {
    for (NSDictionary *item in cases) {
        NSString *input = item[@"input"];
        NSString *expected = item[@"expected"];
        NSString *actual = [[AvroParser sharedInstance] parse:input];
        Report([actual isEqualToString:expected],
               [NSString stringWithFormat:@"parser '%@' -> '%@'", input, expected]);
    }
}

static void RunDatabaseContainsCases(NSArray *cases) {
    for (NSDictionary *item in cases) {
        NSString *input = item[@"input"];
        NSString *expectedMember = item[@"contains"];
        NSArray *matches = [[Database sharedInstance] find:input];

        Report(matches != nil, [NSString stringWithFormat:@"database '%@' returned non-nil", input]);
        Report([matches containsObject:expectedMember],
               [NSString stringWithFormat:@"database '%@' contains '%@'", input, expectedMember]);
    }
}

static void RunDatabaseEmptyCases(NSArray *cases) {
    for (NSString *input in cases) {
        NSArray *matches = [[Database sharedInstance] find:input];
        Report([matches count] == 0,
               [NSString stringWithFormat:@"database '%@' returns empty set", input]);
    }
}

static void RunSuggestionContainsCases(NSArray *cases) {
    for (NSDictionary *item in cases) {
        NSString *input = item[@"input"];
        NSString *expectedMember = item[@"contains"];
        NSMutableArray *suggestions = [[Suggestion sharedInstance] getList:input];

        Report(suggestions != nil, [NSString stringWithFormat:@"suggestion '%@' returned non-nil", input]);
        Report([suggestions containsObject:expectedMember],
               [NSString stringWithFormat:@"suggestion '%@' contains '%@'", input, expectedMember]);

        // Production flow clears this list from controller; mimic that so cases are isolated.
        [suggestions removeAllObjects];
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *cwd = [fileManager currentDirectoryPath];

        NSString *resourceDir = cwd;
        if (argc > 2) {
            resourceDir = [NSString stringWithUTF8String:argv[2]];
        }
        setenv("IAVRO_RESOURCE_DIR", [resourceDir UTF8String], 1);

        NSString *tempHome = [cwd stringByAppendingPathComponent:@"build/regression-home"];
        NSError *dirError = nil;
        [fileManager createDirectoryAtPath:tempHome withIntermediateDirectories:YES attributes:nil error:&dirError];
        if (dirError) {
            fprintf(stderr, "Unable to create temp HOME at %s: %s\n", [tempHome UTF8String], [[dirError localizedDescription] UTF8String]);
            return 2;
        }
        setenv("HOME", [tempHome UTF8String], 1);

        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"IncludeDictionary"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"EnablePerfLog"];

        NSString *fixturePath = @"tests/fixtures/regression_cases.json";
        if (argc > 1) {
            fixturePath = [NSString stringWithUTF8String:argv[1]];
        }

        NSDictionary *fixtures = LoadFixtures(fixturePath);
        if (!fixtures) {
            return 2;
        }

        RunParserCases(fixtures[@"parser"]);
        RunDatabaseContainsCases(fixtures[@"database_contains"]);
        RunDatabaseEmptyCases(fixtures[@"database_empty"]);
        RunSuggestionContainsCases(fixtures[@"suggestion_contains"]);

        if (gFailures == 0) {
            fprintf(stdout, "All regression cases passed.\n");
            return 0;
        }

        fprintf(stderr, "%lu regression case(s) failed.\n", (unsigned long)gFailures);
        return 1;
    }
}
