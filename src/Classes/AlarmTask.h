//
//  AlarmTask.h
//  PDX Bus
//
//  Created by Andrew Wallace on 1/30/11.
//  Copyright 2011. All rights reserved.
//



/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "BackgroundTaskContainer.h"
#import "ScreenConstants.h"
#import "AlarmCell.h"
#import "DebugLogging.h"

#define kStopIdNotification @"stopId"
#define kAlarmBlock			@"alarmBlock"
#define kStopMapDescription @"stopDesc"
#define kStopMapLat			@"mapLat"
#define kStopMapLng			@"mapLng"
#define kCurrLocLat			@"curLat"
#define kCurrLocLng			@"curLng"
#define kCurrTimestamp		@"curTimestamp"
#define kDoNotDisplayIfActive @"not if active"
#define kNoBadge            @"no badge"

typedef enum AlarmStateTag {
	AlarmStateFetchArrivals,
	AlarmStateNearlyArrived,
	AlarmStateAccurateLocationNeeded,
	AlarmStateAccurateInitiallyThenInaccurate,
	AlarmStateInaccurateLocationNeeded,
	AlarmFired
} AlarmLocationNeeded;

#ifdef DEBUGLOGGING
// #define DEBUG_ALARMS
#endif

@protocol AlarmObserver <NSObject> 

- (void)taskStarted:(id)task;
- (void)taskUpdate:(id)task;
- (void)taskDone:(id)task;

@end

@class AlarmTaskList;

@interface AlarmTask : NSObject   {

	NSString *					_desc;
	AlarmLocationNeeded			_alarmState;
	NSString *					_stopId;
	id<AlarmObserver>			_observer;
	UILocalNotification *		_alarm;
#ifdef DEBUG_ALARMS
	NSMutableArray *			_dataReceived;
	bool						_done;
#endif
	NSDate *					_nextFetch;
    bool                        _alarmWarningDisplayed;
	
}

@property (nonatomic, retain)	NSString *desc;
@property (nonatomic)			AlarmLocationNeeded alarmState;
@property (nonatomic, retain)   NSDate *nextFetch;

@property (nonatomic, retain)	NSString * stopId;
@property (nonatomic, assign)	id<AlarmObserver> observer; // weak
@property (retain)				UILocalNotification *alarm;
@property (readonly, nonatomic) int threadReferenceCount;
@property (nonatomic)           bool alarmWarningDisplayed;

#ifdef DEBUG_ALARMS
@property (retain) NSMutableArray *dataReceived;
- (void)showMap:(UINavigationController *)navController;
#endif

- (NSString *)key;
- (void)cancelTask;
- (void)startTask;
- (int)internalDataItems;
- (NSString *)internalData:(int)item;
- (NSDate *)fetch:(AlarmTaskList*)parent;

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
		   fromLocation:(CLLocation *)oldLocation;

- (void)alert:(NSString *)string 
	 fireDate:(NSDate*)fireDate button:(NSString *)button userInfo:(NSDictionary *)userInfo defaultSound:(bool)defaultSound; 

- (void)cancelNotification;
- (NSString *)cellDescription;
- (NSString *)cellToGo;
- (void)showToUser:(BackgroundTaskContainer *)backgroundTask;
- (NSString *)icon;
- (UIColor *)color;
- (NSString *)cellReuseIdentifier:(NSString *)identifier width:(ScreenType)width;
- (void)populateCell:(AlarmCell *)cell;
- (NSDate*)earlierAlert:(NSDate *)alert;
- (NSString*)appState;


@end
