//
//  DebugInterfaceController.m
//  PDX Bus
//
//  Created by Andrew Wallace on 7/31/16.
//  Copyright © 2016 Teleportaloo. All rights reserved.
//

#import "DebugInterfaceController.h"
#import "UserFaves.h"
#import "DebugLogging.h"

@interface DebugInterfaceController ()

@end

@implementation DebugInterfaceController

- (void)dealloc
{
    self.CommuterStatus = nil;
    [super dealloc];
}


- (void)reloadData
{
    NSDictionary *commuter = [[SafeUserData sharedInstance] checkForCommuterBookmarkShowOnlyOnce:NO];
    
    if (commuter == nil)
    {
        self.CommuterStatus.text = @"No commuter bookmark configured for this time.";
    }
    else
    {
        NSDate *lastRun = [SafeUserData sharedInstance].lastRun;
        
        self.CommuterStatus.text = commuter[kUserFavesChosenName];
        
        if (lastRun !=nil)
        {            
            self.CommuterStatus.text = [NSString stringWithFormat:@"%@ last run %@",
                                        commuter[kUserFavesChosenName],
                                        [NSDateFormatter localizedStringFromDate:lastRun dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle]];
            
            
        }
        else
        {
            
            self.CommuterStatus.text = commuter[kUserFavesChosenName];
            
        }
    }

    
}
- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    
    // Configure interface objects here.
    [self reloadData];
   }

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

- (IBAction)ClearCommuterBookmark {
    SafeUserData *prefs = [SafeUserData sharedInstance];
    
    prefs.readOnly = NO;
    
    [[SafeUserData sharedInstance] setLastRun:nil];
    
     prefs.readOnly = YES;
    
    [self reloadData];

}
@end



