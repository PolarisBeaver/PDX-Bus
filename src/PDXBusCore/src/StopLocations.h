//
//  StopLocations.h
//  PDX Bus
//



/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import <sqlite3.h>
#import <CoreLocation/CoreLocation.h>
#import "DebugLogging.h"


#define kIncompleteDatabase @"incomplete"
#define kUnknownDatabase @"unknown"
#define kOldDatabase2    @"stopLocations2.sql"
#define kOldDatabase1    @"stopLocations.sql"
#define kRailOnlyDB      @"railLocations"
#define kSqlFile		 @"sql"
#define kSqlTrue	1
#define kSqlFalse	0

#define kDistNextToMe (kDistMile / 10)
#define kDistHalfMile 804.67200
#define kDistMile	  1609.344
#define kMaxStops	  12
#define kAccNextToMe  150
#define kAccHalfMile  150
#define kAccClosest	  250
#define kAccMile	  300
#define kAcc3Miles	  800
#define kDistMax	  16093.44  // 10 miles in meters
// #define kAnyDist	  0.0

@interface StopLocations : NSObject {
	sqlite3 *           _database;
	NSString *          _path;
	NSMutableArray *    _nearestStops;
	sqlite3_stmt *      _insert_statement;
	sqlite3_stmt *      _select_statement;
	sqlite3_stmt *      _replace_statement;
    bool                _writable;
}


@property (nonatomic, copy)   NSString *path;
@property (nonatomic, retain) NSMutableArray *nearestStops;
@property (nonatomic, readonly) bool isEmpty;

+ (StopLocations*)getDatabase;
+ (StopLocations*)getWritableDatabase;
+ (void)quit;

- (BOOL)insert:(int) locid lat:(double)lat lng:(double)lng rail:(bool)rail;
@property (nonatomic, readonly) BOOL clear;
- (void)close;
@property (nonatomic, getter=getNumberOfStops, readonly) int numberOfStops;
@property (nonatomic, getter=getFileSize, readonly) unsigned long long fileSize;


// This function is deprecated for now as there is a TriMet call for this.
// - (BOOL)findNearestStops:(CLLocation *)here maxToFind:(int)max minDistance:(double)min railOnly:(bool)railOnly;
- (CLLocation*) getLocation:(NSString *)stopID;

@end
