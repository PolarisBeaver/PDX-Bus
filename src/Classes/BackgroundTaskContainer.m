//
//  BackgroundTaskContainer.m
//  PDX Bus
//
//  Created by Andrew Wallace on 2/20/10.
//



/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "BackgroundTaskContainer.h"
#import "TriMetTimesAppDelegate.h"
#import "AppDelegateMethods.h"
#import "DebugLogging.h"



@interface BackgroundTaskContainer()

@property (atomic, readonly)	NSThread * backgroundThread;
@property (atomic, retain)      NSThread * thisBackgroundThread;

@end

@implementation BackgroundTaskContainer

@synthesize progressModal			= _progressModal;
@synthesize callbackComplete		= _callbackComplete;
@synthesize callbackWhenFetching	= _callbackWhenFetching;
@dynamic backgroundThread;
@synthesize title                   = _title;
@synthesize help                    = _help;
@synthesize errMsg                  = _errMsg;
@synthesize controllerToPop         = _controllerToPop;

static NSThread *singletonBackgroundThread = nil;
static NSCondition *condition = nil;

- (void)cancel
{
    DEBUG_FUNC();
    if (self.thisBackgroundThread!=nil)
    {
        [self.backgroundThread cancel];
    }
    else if (singletonBackgroundThread!=nil)
    {
        DEBUG_LOG(@"Would have cancelled the wrong thread");
    }
}

- (bool)running
{
    return (self.thisBackgroundThread != nil);
}

- (void)dealloc {
	self.progressModal = nil;
	self.callbackComplete = nil;
	self.callbackWhenFetching = nil;
    self.errMsg           = nil;
    self.controllerToPop  = nil;
    self.help             = nil;
    self.title            = nil;
    self.thisBackgroundThread = nil;
    [super dealloc];
}

+ (BackgroundTaskContainer*) create:(id<BackgroundTaskDone>) done
{
	BackgroundTaskContainer * btc = [[[BackgroundTaskContainer alloc] init] autorelease];
	
	btc.callbackComplete = done;	
	return btc;
		
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            condition = [[NSCondition alloc] init];
        });
    }
    
    return self;
}

- (NSThread*)backgroundThread
{
    return self.thisBackgroundThread;
}

- (void) runSyncOnMainQueueWithoutDeadlocking: (void (^)(void)) block
{
    if ([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

- (void)privateSetBackgroundThread:(NSThread*)newBackgroundThread
{
    DEBUG_FUNC();
    if (newBackgroundThread!=nil)
    {
        [condition lock];
    
        while (singletonBackgroundThread!=nil)
        {
            DEBUG_LOG(@"Waiting");
            [condition wait];
            DEBUG_LOG(@"Got signal");
        }

        singletonBackgroundThread = [newBackgroundThread retain];
        self.thisBackgroundThread = singletonBackgroundThread;
        
        [condition unlock];
    }
    else
    {
        [condition lock];
        
        if (singletonBackgroundThread!=nil)
        {
            [singletonBackgroundThread release];
            singletonBackgroundThread = nil;
            self.thisBackgroundThread = singletonBackgroundThread;
        }
        // DEBUG_LOG(@"Signal");
        [condition signal];
        [condition unlock];
    }
}

- (void) ProgressDelegateCancel
{
	[self.backgroundThread cancel];
}

-(void)backgroundStart:(int)items title:(NSString *)title
{
    self.title = title;
    self.errMsg = nil;

    [self privateSetBackgroundThread:[NSThread currentThread]];
    
    [self runSyncOnMainQueueWithoutDeadlocking:^{
        TriMetTimesAppDelegate *app = [TriMetTimesAppDelegate sharedInstance];
        
        if (self.progressModal == nil)
        {
            
            if ([self.callbackComplete respondsToSelector:@selector(backgroundTaskStarted)])
            {
                [self.callbackComplete backgroundTaskStarted];
            }
            
            self.progressModal = [ProgressModalView initWithSuper:app.window items:items
                                                            title:self.title
                                                         delegate:(self.backgroundThread!=nil?self:nil)
                                                      orientation:[self.callbackComplete BackgroundTaskOrientation]];
            
            [app.window addSubview:self.progressModal];
            
            [self.progressModal addHelpText:self.help];
        }
        else
        {
            self.progressModal.totalItems = items;
        }
        
    }];
    
    if ([self.callbackComplete respondsToSelector:@selector(backgroundTaskWait)])
    {
        while([self.callbackComplete backgroundTaskWait])
        {
            [NSThread sleepForTimeInterval:0.3];
        }
    }	
}

-(void)backgroundSubtext:(NSString *)subtext
{
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       [self.progressModal addSubtext:subtext];
                   });
}

-(void)backgroundItemsDone:(int)itemsDone
{
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       [self.progressModal itemsDone:itemsDone];
                   });
}

-(void)backgroundItems:(int)totalItems
{
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       [self.progressModal totalItems:totalItems];
                   });
}


-(void)finish
{
    DEBUG_FUNC();
    
    bool cancelled = (self.backgroundThread !=nil && self.backgroundThread.cancelled);
    [self.callbackComplete BackgroundTaskDone:self.controllerToPop cancelled:cancelled];
    self.controllerToPop = nil;
    
    self.callbackWhenFetching = nil;
	self.progressModal = nil;
    [self privateSetBackgroundThread:nil];
}

-(void)backgroundCompleted:(UIViewController *)viewController
{
    dispatch_async(dispatch_get_main_queue(),
                   ^{
                       self.controllerToPop = viewController;
                       
                       if (self.progressModal)
                       {
                           [self.progressModal removeFromSuperview];
                       }
                       
                       if (self.errMsg)
                       {
                           TriMetTimesAppDelegate *app = [TriMetTimesAppDelegate sharedInstance];
                           
                           UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil
                                                                                          message:self.errMsg
                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                           
                           
                           [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"button text") style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
                               [self finish];
                           }]];
                           
                           [app.navigationController.topViewController presentViewController:alert animated:YES completion:nil];
                       }
                       else
                       {
                          
                           
                           [self finish];
                       }
                   });
}

- (void)backgroundSetErrorMsg:(NSString *)errMsg
{
    self.errMsg = errMsg;
}

- (void)BackgroundSetHelpText:(NSString *)helpText
{
    [self.progressModal addHelpText:helpText];
}


@end
