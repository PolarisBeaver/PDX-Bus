/**
 * Copyright 2009 Jeff Verkoeyen
 *
 * PDX Bus changes (c) 2012 Andrew Wallace
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <UIKit/UIKit.h>

@protocol CancelDelegate;

@interface OverlayView : UIView {
	UIImageView *imageView;
	NSMutableArray *_points;
	UIToolbar *toolbar;
    UILabel *instructionsLabel;
	id<CancelDelegate> delegate;
	BOOL oneDMode;
    CGRect cropRect;
    NSString *displayedMessage;
    
}

@property (nonatomic, retain) NSMutableArray*  points;
@property (nonatomic, assign) id<CancelDelegate> delegate;
@property (nonatomic, assign) BOOL oneDMode;
@property (nonatomic, assign) CGRect cropRect;
@property (nonatomic, copy)   NSString *displayedMessage;
@property (nonatomic, retain) UIToolbar *toolbar;


- (instancetype)initWithFrame:(CGRect)theFrame cancelEnabled:(BOOL)isCancelEnabled oneDMode:(BOOL)isOneDModeEnabled showLicense:(BOOL)shouldShowLicense;
- (instancetype)initWithFrame:(CGRect)theFrame cancelEnabled:(BOOL)isCancelEnabled oneDMode:(BOOL)isOneDModeEnabled;

- (void)setPoint:(CGPoint)point;
+ (bool)torchSupported;

@end

@protocol CancelDelegate
- (void)cancelled;
@end
