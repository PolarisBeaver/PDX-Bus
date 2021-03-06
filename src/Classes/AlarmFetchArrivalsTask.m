//
//  AlarmFetchArrivalsTask.m
//  PDX Bus
//
//  Created by Andrew Wallace on 1/29/11.
//  Copyright 2011. All rights reserved.
//



/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "AlarmFetchArrivalsTask.h"
#import "DebugLogging.h"
#import "DepartureTimesView.h"
#import "AlarmTaskList.h"
#import "DepartureData+iOSUI.h"


#define kTolerance	30

@implementation AlarmFetchArrivalsTask

@synthesize block		= _block;
@synthesize departures	= _departures;
@synthesize minsToAlert = _minsToAlert;
@synthesize lastFetched = _lastFetched;
@synthesize display     = _display;

- (void)dealloc
{
    
    self.block			= nil;
    self.departures		= nil;
    self.lastFetched	= nil;
    self.observer		= nil;
    self.display        = nil;
    
    [super dealloc];
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        self.alarmState = AlarmStateFetchArrivals;
        
                

    }
    return self;
}



- (NSDate *)fetch:(AlarmTaskList*)parent
{
    bool taskDone			= NO;
    NSDate *departureDate	= nil;
    NSTimeInterval waitTime;
    NSDate *	next		= nil;
    
    [self.departures getDeparturesForLocation:self.stopId block:self.block];
    
    if (self.departures.gotData && self.departures.count >0)
    {
        @synchronized (self.lastFetched)
        {
            self.lastFetched = self.departures[0];
        }
        _queryTime = self.departures.queryTime;
    }
    else if (self.lastFetched == nil)
    {
        [self alert:NSLocalizedString(@"PDX Bus was not able to get the time for this arrival", @"arrival alarm error")
           fireDate:nil
             button:nil
           userInfo:nil
       defaultSound:YES];
        taskDone = YES;
    }
    else
    {
        departureDate = TriMetToNSDate(self.lastFetched.departureTime);
        
        
        // No new data here - the bus has probably come by this point.  If it has then this is the time to stop.
        if (departureDate == nil || [departureDate compare:[NSDate date]] != NSOrderedDescending)
        {
            taskDone = YES;
        }
    }
    
    if (!taskDone)
    {
        departureDate	= TriMetToNSDate(self.lastFetched.departureTime);
        waitTime		= departureDate.timeIntervalSinceNow;
        
#ifdef DEBUG_ALARMS
        DEBUG_LOG(@"Dep time %@\n", [NSDateFormatter localizedStringFromDate:departureDate
                                                                   dateStyle:NSDateFormatterMediumStyle
                                                                   timeStyle:NSDateFormatterLongStyle]);
#endif
        
        if (self.observer)
        {
            self.display = nil;
            [self.observer taskUpdate:self];
        }
        
        bool externalDisplay = [parent updateAllExternalDisplays:self];
        
        // Update the alert with the time we have
        NSDate *alarmTime = [departureDate dateByAddingTimeInterval:(NSTimeInterval)(-(NSTimeInterval)(self.minsToAlert * 60.0 + 30.0))];
        NSString *alertText = nil;
        
        if (self.minsToAlert <= 0)
        {
            alertText = [NSString stringWithFormat:NSLocalizedString(@"\"%@\" is due at %@", @"alarm message"),
                         self.lastFetched.shortSign,
                         self.lastFetched.locationDesc
                         ];
        }
        else if (self.minsToAlert == 1)
        {
            alertText = [NSString stringWithFormat:NSLocalizedString(@"\"%@\" 1 minute way from %@", @"alarm message"),
                         self.lastFetched.shortSign,
                         self.lastFetched.locationDesc
                         ];
        }
        else
        {
            alertText = [NSString stringWithFormat:NSLocalizedString(@"\"%@\" is %d minutes away from %@", @"alarm message"),
                         self.lastFetched.shortSign,
                         self.minsToAlert,
                         self.lastFetched.locationDesc
                         ];
        }
        
        // if (self.alarm == nil) //  || ![self.alarm.fireDate isEqualToDate:alarmTime])
        {
            [self alert:alertText
               fireDate:alarmTime
                 button:NSLocalizedString(@"Show arrivals", @"alert text")
               userInfo:@{
                          kStopIdNotification   : self.stopId,
                          kAlarmBlock           : self.block }
           defaultSound:NO];
        }
        
        
        int secs = (waitTime - (self.minsToAlert * 60));
        
        if (secs > 8*60)
        {
            next = [NSDate dateWithTimeIntervalSinceNow:4 * 60];
        }
        else if (secs > 120)
        {
            next = [NSDate dateWithTimeIntervalSinceNow:secs/2];
            
        }
        else if (secs > 60)
        {
            // suspend until the actual time
            next = [NSDate dateWithTimeIntervalSinceNow:30];
        }
        else if (secs > 0)
        {
            next = alarmTime;
            self.alarmState = AlarmStateNearlyArrived;
        }
        else
        {
            next = nil;
            self.alarmState = AlarmFired;
        }
        
        
        if (secs > 30 && externalDisplay)
        {
            next = [NSDate dateWithTimeIntervalSinceNow:30];
        }
        
        
    }
    
    if (taskDone)
    {
        next = nil;
        self.alarmState = AlarmFired;
        
        [parent endExternalDisplayForTask:self];
        
       
    }
    
#ifdef DEBUG_ALARMS
#define kLastFetched @"LF"
#define kNextFetch @"NF"
#define kAppState @"AppState"
    NSDictionary *dict = @{
                           kLastFetched     : self.lastFetched,
                           kNextFetch       : (next ? next : [NSDate date]),
                           kAppState        : [self appState] };
    [self.dataReceived addObject:dict];
#endif
    
    
    return next;
}

- (void)startTask
{
    self.departures = [XMLDepartures xml];
    self.departures.giveUp = 30;  // the background task must never be blocked for more that 30 seconds.
    
    if (self.observer)
    {
        [self.observer taskStarted:self];
    }
}


- (NSString *)key
{
    return [NSString stringWithFormat:@"%@+%@", self.stopId, self.block];
}

- (void)cancelTask
{
    [self retain];
    [self cancelNotification];
    [self.observer taskDone:self];
    self.observer = nil;
    [self release];
}

#ifdef DEBUG_ALARMS
- (int)internalDataItems
{
    return (int)self.dataReceived.count+1;
}

- (NSString *)internalData:(int)item
{
    NSMutableString *str = [NSMutableString string];
    
    
    if (item == 0)
    {
        UIApplication*    app = [UIApplication sharedApplication];
        [str appendFormat:@"alerts: %u", (int)app.scheduledLocalNotifications.count];
    }
    else
    {
        NSDictionary *dict = self.dataReceived[item-1];
        DepartureData *dep = dict[kLastFetched];
        
        NSDateFormatter *dateFormatter = [NSDateFormatter alloc].init.autorelease;
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [dateFormatter setTimeStyle:NSDateFormatterLongStyle];
        
        [str appendFormat:@"%@\n", dep.routeName];
        [str appendFormat:@"mins %d\n", dep.minsToArrival];
        [str appendFormat:@"secs %lld\n", dep.secondsToArrival];
        
        [str appendFormat:@"QT %@\n", [dateFormatter stringFromDate:TriMetToNSDate(dep.queryTime)]];
        
        NSDate *departureDate	= TriMetToNSDate(dep.departureTime);
        NSDate *alarmTime = [departureDate dateByAddingTimeInterval:(NSTimeInterval)(-(NSTimeInterval)(self.minsToAlert * 60.0 + 30.0))];
        
        [str appendFormat:@"DT %@\n", [dateFormatter stringFromDate: departureDate ]];
        [str appendFormat:@"AT %@\n", [dateFormatter stringFromDate: alarmTime ]];
        [str appendFormat:@"NF %@\n", [dateFormatter stringFromDate: dict[kNextFetch]]];
        [str appendFormat:@"AS %@\n", dict[kAppState]];
    }
    return str;
    
}
#endif

- (void)showToUser:(BackgroundTaskContainer *)backgroundTask
{
    [[DepartureTimesView viewController] fetchTimesForLocationAsync:backgroundTask loc:self.stopId block:self.block];
}

- (NSString *)cellToGo
{
    NSString *str = @"";
    @synchronized (self.lastFetched)
    {
        
        if (self.lastFetched !=nil)
        {
            NSDateFormatter *dateFormatter = [NSDateFormatter alloc].init.autorelease;
            dateFormatter.dateStyle = NSDateFormatterNoStyle;
            dateFormatter.timeStyle = NSDateFormatterShortStyle;
            NSDate *departureDate = TriMetToNSDate(self.lastFetched.departureTime);
            
            NSTimeInterval secs = ((double)self.minsToAlert * (-60.0));
            
            NSDate *alarmDate = [NSDate dateWithTimeInterval:secs sinceDate:departureDate];
            if (self.alarmState == AlarmFired)
            {
                str = [NSString stringWithFormat:NSLocalizedString(@"Alarm sounded at %@", @"Alarm was done at time {time}"), [dateFormatter stringFromDate: alarmDate]];
            }
            else
            {
                switch (self.minsToAlert)
                {
                    case 0:
                        str = [NSString stringWithFormat:NSLocalizedString(@"Arrival at %@", @"Alarm will be done at time {time}"), [dateFormatter stringFromDate: departureDate]];
                        break;
                    case 1:
                        str = [NSString stringWithFormat:NSLocalizedString(@"1 min before arrival at %@", @"Alarm will be done at time {time}"), [dateFormatter stringFromDate: departureDate], self.display];
                        break;
                    default:
                        str = [NSString stringWithFormat:NSLocalizedString(@"%d mins before arrival at %@", @"Alarm will be done at time {time}"), self.minsToAlert, [dateFormatter stringFromDate: departureDate]];
                        break;
                }
                
                if (self.display)
                {
                    str = [str stringByAppendingFormat:@" (%@)", self.display];
                }
            }
        }
    }
    return str;
}

- (int)threadReferenceCount
{
    return 1;
}

@end



