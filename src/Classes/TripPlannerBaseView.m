//
//  TripPlannerBaseView.m
//  PDX Bus
//
//  Created by Andrew Wallace on 9/12/10.
//  Copyright 2010. All rights reserved.
//



/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "TripPlannerBaseView.h"
#import "TripPlannerOptions.h"

@implementation TripPlannerBaseView

@synthesize tripQuery = _tripQuery;

- (void)dealloc {
	self.tripQuery = nil;
	[super dealloc];
}

@end
