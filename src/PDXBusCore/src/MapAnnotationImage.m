//
//  MapAnnotationImage.m
//  PDXBusCore
//
//  Created by Andrew Wallace on 10/20/15.
//  Copyright © 2015 Teleportaloo. All rights reserved.
//



/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "MapAnnotationImage.h"
#import "DebugLogging.h"
#import "UserPrefs.h"

#define kIconUp				 @"icon_arrow_up.png"
#define kIconUp2x            @"icon_arrow_up@2x.png"

@implementation MapAnnotationImage

@synthesize imageCache = _imageCache;
@synthesize lastMapRotation = _lastMapRotation;
@synthesize imageFile = _imageFile;
@synthesize forceRetinaImage = _forceRetinaImage;

static MapAnnotationImage *singleton = nil;

- (instancetype)init {
    if ((self = [super init]))
    {
        self.imageCache = [NSMutableDictionary dictionary];
        self.imageFile = [UserPrefs sharedInstance].busIcon;
        _hits = 0;
    }
    
    return self;
}

+ (MapAnnotationImage*)autoSingleton
{
    @synchronized (self) {
        
        if (singleton == nil)
        {
            singleton = [[[MapAnnotationImage alloc] init] autorelease];
            
            return singleton;
        }
        else
        {
            return [[singleton retain] autorelease];
        }
    }

    return nil;
}

- (void)dealloc
{
    self.imageCache = nil;
    self.imageFile = nil;
    
    @synchronized (self) {
        singleton = nil;
    }
    
    DEBUG_LOG(@"Image cache removed.\n");
    
    [super dealloc];
}


- (UIImage*)rotatedImage:(UIImage*)sourceImage byDegreesFromNorth:(double)degrees
{
    
    CGSize rotateSize =  sourceImage.size;
    UIGraphicsBeginImageContextWithOptions(rotateSize, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, rotateSize.width/2, rotateSize.height/2);
    CGContextRotateCTM(context, ( degrees * M_PI/180.0 ) );
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(UIGraphicsGetCurrentContext(),
                       CGRectMake(-rotateSize.width/2,-rotateSize.height/2,rotateSize.width, rotateSize.height),
                       sourceImage.CGImage);
    UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return rotatedImage;
}

- (UIImage *)tintImage:(UIImage *)sourceImage color:(UIColor *)color
{
    CGRect rect = { 0,0, sourceImage.size.width, sourceImage.size.height};
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, color.CGColor);
    
    CGContextFillRect(context, rect); // draw base
    
    [sourceImage drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1.0]; // draw image
    
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return tintedImage;
    
}

- (UIImage *)getImage:(double)rotation mapRotation:(double)mapRotation bus:(bool)bus
{
    if ( ABS(mapRotation - self.lastMapRotation) > 0.001 )
    {
        self.imageCache = [NSMutableDictionary dictionary];
        self.lastMapRotation = mapRotation;
    }
    
    double total = rotation - mapRotation;
    
    NSString *image = self.forceRetinaImage ? kIconUp2x : kIconUp;
    
    /*
    if (bus)
    {
        // rotation += 360*3;   // this just makes them different!
        // image = self.imageFile;
    }
    */
    
    UIImage *arrow = self.imageCache[@(rotation)];
    
    if (arrow == nil)
    {
        arrow = [self rotatedImage:[UIImage imageNamed:image] byDegreesFromNorth:total];
 
        self.imageCache[@(rotation)] = arrow;
        
        DEBUG_LOG(@"Cache miss %03u %-3.2f\n", (unsigned int)self.imageCache.count, rotation );
    }
    else
    {
        DEBUG_LOG(@"Cache hit  %03u %-3.2f\n", (unsigned int)++_hits, rotation);
    }
    
    return arrow;
    
}

- (bool)tintableImage
{
    if ([self.imageFile characterAtIndex:0] == 'c')
    {
        return NO;
    }
    return YES;
}

- (void)clearCache
{
    self.imageCache = [NSMutableDictionary dictionary];
}


@end
