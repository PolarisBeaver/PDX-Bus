//
//  BlockColorView.h
//  PDX Bus
//
//  Created by Andrew Wallace on 10/2/17.
//  Copyright © 2017 Teleportaloo. All rights reserved.
//



/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import <UIKit/UIKit.h>

@interface BlockColorView : UIView
{
    UIColor *_color;
}

@property (nonatomic, retain) UIColor *color;

@end
