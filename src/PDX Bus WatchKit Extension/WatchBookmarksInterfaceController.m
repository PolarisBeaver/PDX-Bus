//
//  WatchBookmarksInterfaceController.m
//  PDX Bus
//
//  Created by Andrew Wallace on 4/18/15.
//  Copyright (c) 2015 Teleportaloo. All rights reserved.
//



/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "WatchBookmarksInterfaceController.h"
#import "UserFaves.h"
#import "WatchBookmark.h"
#import "TriMetXML.h"
#import "StopNameCacheManager.h"
#import "WatchArrivalsContextBookmark.h"
#import "StringHelper.h"
#import "DebugLogging.h"
#import "WatchNearbyInterfaceController.h"
#import "NumberPadInterfaceController.h"
#import "AlertInterfaceController.h"
#import "WatchAppContext.h"
#import "ExtensionDelegate.h"

@interface WatchBookmarksInterfaceController()

@end


@implementation WatchBookmarksInterfaceController


@synthesize bookmarksContext    = _bookmarksContext;
@synthesize displayedItems      = _displayedItems;


- (void)dealloc
{
    self.bookmarksContext   = nil;
    self.displayedItems     = nil;
    self.bookmarkLabel      = nil;
    self.bookmarkTable      = nil;
    self.mainTextLabel      = nil;
    self.session            = nil;
    self.topGroup           = nil;
    [super dealloc];
}

- (void)cacheUpdated:(id)unused
{
    [self displayStopsInBookmark];
}

- (id)backgroundTask
{
    // [self startBackgroundTask];
    bool updated = NO;
    StopNameCacheManager *stopNameCache = [TriMetXML getStopNameCacheManager];
    for (NSString *loc in self.bookmarksContext.singleBookmark) {
        
        [stopNameCache getStopName:loc fetchAndCache:YES updated:&updated];
        
        if (updated)
        {
            [self performSelectorOnMainThread:@selector(cacheUpdated:) withObject:nil waitUntilDone:NO];
        }
    }
    return nil;
}

- (void)displayStopsInBookmark
{
    self.title = self.bookmarksContext.title;
    self.displayedItems = self.bookmarksContext.singleBookmark;
    [self.bookmarkTable setNumberOfRows:self.displayedItems.count withRowType:@"Bookmark"];

    StopNameCacheManager *stopNameCache = [TriMetXML getStopNameCacheManager];
    
    for (NSInteger i = 0; i < self.bookmarkTable.numberOfRows; i++) {
        
        WatchBookmark *row = [self.bookmarkTable rowControllerAtIndex:i];
        NSArray *stopName = [stopNameCache getStopName:self.displayedItems[i] fetchAndCache:NO updated:nil];
        
        [row.bookmarkName setText:stopName[kStopNameCacheShortDescription]];
    }
    
    self.displayedItems = self.bookmarksContext.singleBookmark;
}


- (void)taskFinishedMainThread:(id)result
{
    self.title = self.bookmarksContext.title;
    
    // [self displayStopsInBookmark];
    
   
}

- (void)setupButtonsAndTextTopHidden:(bool)top textHidden:(bool)text
{
    self.topGroup.hidden        = top;
    self.mainTextLabel.hidden   = text;
}

- (void)reloadData
{
    if (self.bookmarksContext == nil || self.bookmarksContext.recents)
    {
        self.displayedItems = nil;
        
        
        // force a reload
        self.faves.appData = nil;
        
        if (self.bookmarksContext == nil)
        {
            self.title = @"PDX Bus";
            if ([WatchAppContext gotBookmarks:NO])
            {
            
                self.displayedItems = self.faves.favesArrivalsOnly;
                self.mainTextLabel.text = [NSString stringWithFormat:@"Note: Set up bookmarks in the iPhone app.\nVersion %@", [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"]];;
                
            }
            else
            {
                self.displayedItems = nil;
                self.mainTextLabel.text = [NSString stringWithFormat:@"Please run the iPhone app once; it will send bookmarks to the watch.\nVersion %@", [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"]];
                
            }
            
            self.bookmarkLabel.hidden = NO;
            
            [self setupButtonsAndTextTopHidden:NO textHidden:NO];
            
            
        } else {
            self.title =  @"Recents";
            self.displayedItems = self.faves.recents;
            
            [self setupButtonsAndTextTopHidden:YES textHidden:YES];
            
             self.bookmarkLabel.hidden = YES;
        }
        
        if (self.displayedItems.count > 0)
        {
            [self.bookmarkTable setNumberOfRows:self.displayedItems.count withRowType:@"Bookmark"];
            
            for (NSInteger i = 0; i < self.bookmarkTable.numberOfRows; i++) {
                
                WatchBookmark *row = [self.bookmarkTable rowControllerAtIndex:i];
                
                NSDictionary *item = self.displayedItems[i];
                
                [row.bookmarkName setText:item[kUserFavesChosenName]];
            }
        }
        else
        {
            if (self.bookmarksContext == nil)
            {
                if ([WatchAppContext gotBookmarks:NO])
                {
                    [self.bookmarkTable setNumberOfRows:1 withRowType:@"No bookmarks"];
                }
            }
            else
            {
                [self.bookmarkTable setNumberOfRows:1 withRowType:@"No recents"];
            }
        }
    }
    else if (self.bookmarksContext.singleBookmark !=nil)
    {
        self.title = @"Loading";
        
        [self displayStopsInBookmark];
        [self startBackgroundTask];
        
        if (self.bookmarksContext.oneTimeShowFirst)
        {
            self.bookmarksContext.oneTimeShowFirst = NO;
            
            
            [self delayedPush:[WatchArrivalsContextBookmark contextFromBookmark:self.bookmarksContext index:0]];
            
        }
        
        [self setupButtonsAndTextTopHidden:YES textHidden:YES];
        
        self.bookmarkLabel.hidden = YES;
    }
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    
    self.faves = [SafeUserData sharedInstance];
    self.faves.readOnly = YES;
    self.bookmarksContext = context;

    
    if ([WCSession isSupported] && (self.bookmarksContext == nil))
    {
        self.session = [WCSession defaultSession];
        self.session .delegate = self;
        [self.session  activateSession];
        
        if (self.session.applicationContext)
        {
            [WatchAppContext writeAppContext:self.session.applicationContext];
        }
    }
    else
    {
        [self reloadData];
    }
    

}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndex:(NSInteger)rowIndex
{
    if (self.bookmarksContext == nil || self.bookmarksContext.recents)
    {
        if (rowIndex < self.displayedItems.count)
        {
            NSDictionary *selectedItem = self.displayedItems[rowIndex];
            NSString *location = selectedItem[kUserFavesLocation];
            NSString *title    = selectedItem[kUserFavesChosenName];
        
            NSArray *stops = location.arrayFromCommaSeparatedString;
            
            if (stops.count > 1)
            {
                WatchBookmarksContext * context = [WatchBookmarksContext contextWithBookmark:stops title:title locationString:location];
                
                //
                //if (self.bookmarksContext == nil)
                //{
                //    context.oneTimeShowFirst = YES;
                //}
                
                [context pushFrom:self];
                
            }
            else if (stops.count !=0)
            {
                if (self.bookmarksContext.recents)
                {
                    NSMutableArray *recentStops = [NSMutableArray array];
                    
                    for (NSDictionary *item in self.displayedItems)
                    {
                        [recentStops addObject:item[kUserFavesLocation]];
                    }
                    
                    [[WatchArrivalsContextBookmark contextFromRecents:
                      [WatchBookmarksContext contextWithBookmark:recentStops
                                                           title:title
                                                  locationString:location] index:rowIndex] pushFrom:self];
                    

                }
                else
                {
                    [[WatchArrivalsContextBookmark contextWithLocation:location] pushFrom:self];
                }
            }
        }
    }
    else
    {
        [[WatchArrivalsContextBookmark contextFromBookmark:self.bookmarksContext index:rowIndex] pushFrom:self];
    }
    
}

- (void)applicationDidBecomeActive
{
#ifdef DEBUGLOGGING
    bool pushedCommuterBookmark =
#endif
        [self autoCommute];
    DEBUG_LOG(@"Auto-commute? %d", pushedCommuterBookmark);
}

- (void)didAppear
{
    bool pushedCommuterBookmark = NO;
    [SafeUserData sharedInstance].lastRunKey = kLastRunWatch;
    
    WKExtension *extension = [WKExtension sharedExtension];
    
    ExtensionDelegate *delegate = extension.delegate;
    
    // If we are the root display the bookmark
    if (self.bookmarksContext == nil)
    {
        pushedCommuterBookmark = [self delayedDisplayOfCommuterBookmark];
        DEBUG_LOG(@"Root - did  I push? %d", pushedCommuterBookmark);
        [WatchAppContext writeAppContext:self.session.applicationContext];
        
    }
    
    
    
    if (!pushedCommuterBookmark && delegate.justLaunched)
    {
        pushedCommuterBookmark = [self autoCommute];
        DEBUG_LOG(@"Auto-commute? %d", pushedCommuterBookmark);
    }
    
    delegate.justLaunched = NO;
    
    if (!pushedCommuterBookmark)
    {
        if (self.session && self.session.applicationContext)
        {
            [WatchAppContext writeAppContext:self.session.applicationContext];
        }
        [self reloadData];
        
        [self.bookmarksContext updateUserActivity:self];
    }
    
    [super didAppear];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

- (IBAction)menuItemHome {
    [self popToRootController];
}

- (IBAction)enterStopId {
    [self pushControllerWithName:@"Number Pad" context:nil];
}

- (IBAction)menuItemCommute {
    [self forceCommute];
}
- (IBAction)topRecentStops {
    [[WatchBookmarksContext contextForRecents] pushFrom:self];
}

- (IBAction)topLocateStops {
    [self pushControllerWithName:kNearbyScene context:nil];
}

/** Called when the session can no longer be used to modify or add any new transfers and, all interactive messages will be cancelled, but delegate callbacks for background transfers can still occur. This will happen when the selected watch is being changed. */
- (void)sessionDidBecomeInactive:(WCSession *)session
{
    
}

/** Called when all delegate callbacks for the previously selected watch has occurred. The session can be re-activated for the now selected watch using activateSession. */
- (void)sessionDidDeactivate:(WCSession *)session
{
    
}

/** Called when any of the Watch state properties change. */
- (void)sessionWatchStateDidChange:(WCSession *)session
{
    
}

- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary<NSString *, id> *)applicationContext
{
    [WatchAppContext writeAppContext:applicationContext];
    
    [self reloadData];
}


@end



