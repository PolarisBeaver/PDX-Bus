//
//  TripPlannerResultsView.m
//  PDX Bus
//
//  Created by Andrew Wallace on 6/28/09.
//



/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "TripPlannerResultsView.h"
#import "DepartureTimesView.h"
#import "MapViewController.h"
#import "SimpleAnnotation.h"
#import <MessageUI/MFMailComposeViewController.h>
#import "TripPlannerDateView.h"
#import "DepartureTimesView.h"
#import "NetworkTestView.h"
#import "WebViewController.h"
#import "TripPlannerMap.h"
#include "UserFaves.h"
#include "EditBookMarkView.h"
#import <MessageUI/MessageUI.h>
#include "TripPlannerEndPointView.h"
#import <EventKit/EventKit.h>
#import <EventKitUI/EventKitUI.h>
#import "TripPlannerSummaryView.h"
#import "DetoursView.h"
#import "AlarmTaskList.h"
#import "AlarmAccurateStopProximity.h"
#import "LocationAuthorization.h"
#import "StringHelper.h"

#define kRowTypeLeg			0
#define kRowTypeDuration	1
#define kRowTypeFare		2
#define kRowTypeMap			3
#define kRowTypeEmail		4
#define kRowTypeSMS			5
#define kRowTypeCal         6
#define kRowTypeClipboard	7
#define kRowTypeAlarms      8
#define kRowTypeArrivals	9
#define kRowTypeDetours		10
#define kRowAdditionalRows  9

#define kRowTypeError		11
#define kRowTypeReverse		12
#define kRowTypeFrom		13
#define kRowTypeTo			14
#define kRowTypeOptions		15
#define kRowTypeDateAndTime 16


#define kSectionTypeEndPoints	0
#define kSectionTypeOptions		1

#define kDefaultRowHeight		40.0
#define kRowsInDisclaimerSection 2

#define KDisclosure UITableViewCellAccessoryDisclosureIndicator
#define kScheduledText @"The trip planner shows scheduled service only. Check below to see how detours may affect your trip."

@implementation TripPlannerResultsView

@synthesize tripQuery = _tripQuery;
@synthesize calendarItinerary = _calendarItinerary;

- (void)dealloc {
	self.tripQuery = nil;
	self.calendarItinerary = nil;
    self.prototypeTripCell = nil;
    
    if (self.userActivity)
    {
        [self.userActivity invalidate];
        self.userActivity = nil;
    }
    
	[super dealloc];
}

- (instancetype)init
{
	if ((self = [super init]))
	{
		_recentTripItem = -1;
	}
	
	return self;
	
}

- (instancetype)initWithHistoryItem:(int)item
{
	if ((self = [super init]))
	{
		[self setItemFromHistory:item];
	}
	
	return self;
}


- (void)setItemFromArchive:(NSDictionary *)archive
{
    self.tripQuery = [XMLTrips xml];
    
    
    self.tripQuery.userRequest = [TripUserRequest fromDictionary:archive[kUserFavesTrip]];
    // trips.rawData     = trip[kUserFavesTripResults];
    
    [self.tripQuery addStopsFromUserFaves:_userData.faves];
    
    
    [self.tripQuery fetchItineraries:archive[kUserFavesTripResults]];
}

- (void)setItemFromHistory:(int)item
{
	NSDictionary *trip = nil;
	@synchronized (_userData)
	{
		trip = _userData.recentTrips[item];
        
        _recentTripItem = item;
	
        [self setItemFromArchive:trip];
        
	}

}

#pragma mark TableViewWithToolbar methods

- (UITableViewStyle) getStyle
{
	return UITableViewStyleGrouped;
}

- (void)updateToolbarItems:(NSMutableArray *)toolbarItems
{	
	// match each of the toolbar item's style match the selection in the "UIBarButtonItemStyle" segmented control
	UIBarButtonItemStyle style = UIBarButtonItemStylePlain;
	
	
	
	
	// create the system-defined "OK or Done" button
    UIBarButtonItem *bookmark = [[UIBarButtonItem alloc]
                                 initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks
                                 target:self action:@selector(bookmarkButton:)];
	
	bookmark.style = style;
	
	// create the system-defined "OK or Done" button
    UIBarButtonItem *edit = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Redo", @"button text")
															 style:UIBarButtonItemStylePlain 
															target:self 
															action:@selector(showCopy:)];
	
	// create the system-defined "OK or Done" button


	[toolbarItems addObject: bookmark];
	[toolbarItems addObject: [UIToolbar autoFlexSpace]];
	[toolbarItems addObject: edit];
    [toolbarItems addObject: [UIToolbar autoFlexSpace]];
     
    if ([UserPrefs sharedInstance].debugXML)
    {
        [toolbarItems addObject:[self autoXmlButton]];
        [toolbarItems addObject:[UIToolbar autoFlexSpace]];
    }
    
    [self maybeAddFlashButtonWithSpace:NO buttons:toolbarItems big:NO];
	
	[bookmark release];
	[edit release];
}

- (void)appendXmlData:(NSMutableData *)buffer
{
    [self.tripQuery appendQueryAndData:buffer];
}

#pragma mark View methods


- (void)enableArrows:(UISegmentedControl*)seg
{
	[seg setEnabled:(_recentTripItem > 0) forSegmentAtIndex:0];
	
	[seg setEnabled:(_recentTripItem < (_userData.recentTrips.count-1)) forSegmentAtIndex:1];

}


- (void)upDown:(id)sender
{
	UISegmentedControl *segControl = sender;
	switch (segControl.selectedSegmentIndex)
	{
		case 0:	// UIPickerView
		{
			// Up
			if (_recentTripItem > 0)
			{
				[self setItemFromHistory:_recentTripItem-1];
				[self reloadData];
			}
			break;
		}
		case 1:	// UIPickerView
		{
			if (_recentTripItem < (_userData.recentTrips.count-1) )
			{
				[self setItemFromHistory:_recentTripItem+1];
				[self reloadData];
			}
			break;
		}
	}
	[self enableArrows:segControl];
}

- (void)loadView
{
    [super loadView];
    
    [self.table registerNib:[TripItemCell nib] forCellReuseIdentifier:kTripItemCellId];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Trip",@"page title");
    
    _alarmItem      = -1;

	
	if (self.tripQuery.resultFrom != nil && self.tripQuery.resultTo != nil)
	{
		_itinerarySectionOffset = 1; 
	}
	else
	{
		_itinerarySectionOffset = 0;
	}
	
	Class messageClass = (NSClassFromString(@"MFMessageComposeViewController"));
    
    if (messageClass != nil) {          
        // Check whether the current device is configured for sending SMS messages
        if ([messageClass canSendText]) {
            _smsRows = 1;
        }
        else {  
            _smsRows = 0;			
        }
    }
	
	Class eventClass = (NSClassFromString(@"EKEventEditViewController"));
	
	if (eventClass != nil) {
		_calRows = 1;
	}
	else {
		_calRows = 0;
	}
	
	if (_recentTripItem >=0)
	{
		UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[
                                            [TableViewWithToolbar getToolbarIcon7:kIconUp7      old:kIconUp],
                                            [TableViewWithToolbar getToolbarIcon7:kIconDown7    old:kIconDown]] ];
		seg.frame = CGRectMake(0, 0, 60, 30.0);
		seg.momentary = YES;
		[seg addTarget:self action:@selector(upDown:) forControlEvents:UIControlEventValueChanged];
		
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView: seg] autorelease];
		
		[self enableArrows:seg];
		[seg release];
		
	}
    
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

#pragma mark UI helpers

- (NSInteger)sectionType:(NSInteger)section
{
	if (section < _itinerarySectionOffset)	
	{
		return kSectionTypeEndPoints;
	}
	else if ((section - _itinerarySectionOffset) < self.tripQuery.count)
	{
		return kSectionTypeOptions;
	}
	return kSectionRowDisclaimerType;
}

- (TripItinerary *)getSafeItinerary:(NSInteger)section
{
	if ([self sectionType:section] ==  kSectionTypeOptions)
	{
		return self.tripQuery[section - _itinerarySectionOffset]; 
	}
	return nil;
}

- (NSInteger)legRows:(TripItinerary *)it
{
	return it.displayEndPoints.count;
}

- (NSInteger)rowType:(NSIndexPath *)indexPath
{
	NSInteger sectionType = [self sectionType:indexPath.section];
	
	switch (sectionType)
	{
		case kSectionTypeEndPoints:
			return indexPath.row + kRowTypeFrom;
		case kSectionTypeOptions:
		{
			TripItinerary *it = [self getSafeItinerary:indexPath.section];
			NSInteger legs = [self legRows:it];
			
			if (legs == 0)	
			{
				return kRowTypeError;
			}
			
			if (indexPath.row < legs)
			{
				return kRowTypeLeg;
			}
			else
			{
				NSInteger row = 1 + indexPath.row - legs;
				if (row >= kRowTypeFare && ![it hasFare])
				{
					row ++;
				}
				
				if (row >= kRowTypeSMS && _smsRows == 0)
				{
					row ++;
				}
				
				if (row >= kRowTypeCal && _calRows == 0)
				{
					row ++;
				}
				return row;
			}
		}
		case kSectionRowDisclaimerType:
			if (self.tripQuery.reversed || indexPath.row > 0)
			{
				return kSectionRowDisclaimerType;
			}
			else
			{
				return kRowTypeReverse;
			}
	}
	return kSectionRowDisclaimerType;
}


- (NSString *)getTextForLeg:(NSIndexPath *)indexPath
{
	TripItinerary *it = [self getSafeItinerary:indexPath.section];
	
	if (indexPath.row < [self legRows:it])
	{
		return it.displayEndPoints[indexPath.row].displayText;
	}
	
	return nil;
	
}

-(void)showCopy:(id)sender
{
    TripPlannerSummaryView *trip = [TripPlannerSummaryView viewController];
    
    trip.tripQuery = [self.tripQuery createAuto];
    [trip.tripQuery resetCurrentLocation];
    
	[self.navigationController pushViewController:trip animated:YES];
}


- (NSString*)getFromText
{
	//	if (self.tripQuery.fromPoint.useCurrentPosition)
	//	{
	//		return [NSString stringWithFormat:@"From: %@, %@", self.tripQuery.fromPoint.lat, self.tripQuery.fromPoint.lng];
	//	}	
	return self.tripQuery.resultFrom.xdescription;
}

- (NSString*)getToText
{
	//	if (self.tripQuery.toPoint.useCurrentPosition)
	//	{
	//		return [NSString stringWithFormat:@"To: %@, %@", self.tripQuery.toPoint.lat, self.tripQuery.toPoint.lng];
	//	}
	return self.tripQuery.resultTo.xdescription;
}




-(void)selectLeg:(TripLegEndPoint *)leg
{
	NSString *stopId = [leg stopId];
	
	if (stopId != nil)
	{
        DepartureTimesView *departureViewController = [DepartureTimesView viewController];
		
		departureViewController.displayName = @"";
		[departureViewController fetchTimesForLocationAsync:self.backgroundTask loc:stopId];
	}
	else if (leg.xlat !=0 && leg.xlon !=0)
	{
        MapViewController *mapPage = [MapViewController viewController];
        SimpleAnnotation *pin = [SimpleAnnotation annotation];
		mapPage.callback = self.callback;
		pin.coordinate =  leg.loc.coordinate;
		pin.pinTitle = leg.xdescription;
		pin.pinColor = MKPinAnnotationColorPurple;
		
		
		[mapPage addPin:pin];
		mapPage.title = leg.xdescription; 
		[self.navigationController pushViewController:mapPage animated:YES];
	}	
	
	
}

#pragma mark UI Callback methods

-(void)bookmarkButton:(UIBarButtonItem*)sender
{
	NSString *desc = nil;
    int  bookmarkItem = kNoBookmark;
	@synchronized (_userData)
	{
		int i;

		TripUserRequest * req = [[[TripUserRequest alloc] init] autorelease];
	
		for (i=0; _userData.faves!=nil &&  i< _userData.faves.count; i++)
		{
			NSDictionary *bm = _userData.faves[i];
			NSDictionary * faveTrip = (NSDictionary *)bm[kUserFavesTrip];
		
			if (bm!=nil && faveTrip != nil)
			{
				[req readDictionary:faveTrip];
				if ([req equalsTripUserRequest:self.tripQuery.userRequest])
				{
					bookmarkItem = i;
					desc = bm[kUserFavesChosenName];
					break;
				}
			}
		
		}
	}
	
	if (bookmarkItem == kNoBookmark)
    {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Bookmark Trip",@"alert title")
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add new bookmark", @"button text")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action){
                                                    EditBookMarkView *edit = [EditBookMarkView viewController];
                                                    // [edit addBookMarkFromStop:self.bookmarkDesc location:self.bookmarkLoc];
                                                    [edit addBookMarkFromUserRequest:self.tripQuery];
                                                    // Push the detail view controller
                                                    [self.navigationController pushViewController:edit animated:YES];
                                                }]];
        
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"button text") style:UIAlertActionStyleCancel handler:nil]];
        
        alert.popoverPresentationController.barButtonItem = sender;
        
        [self presentViewController:alert animated:YES completion:^{
            [self clearSelection];
        }];
    }
	else {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:desc
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Delete this bookmark", @"button text")
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction *action){
                                                    [_userData.faves removeObjectAtIndex:bookmarkItem];
                                                    [self favesChanged];
                                                    [_userData cacheAppData];
                                                }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Edit this bookmark", @"button text")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action){
                                                    EditBookMarkView *edit = [EditBookMarkView viewController];
                                                    [edit editBookMark:_userData.faves[bookmarkItem] item:bookmarkItem];
                                                    // Push the detail view controller
                                                    [self.navigationController pushViewController:edit animated:YES];
                                                }]];
        
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"button text") style:UIAlertActionStyleCancel handler:nil]];
        
        alert.popoverPresentationController.barButtonItem = sender;
        
        [self presentViewController:alert animated:YES completion:^{
            [self clearSelection];
        }];
        
	}	
}



#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.tripQuery.count+1+_itinerarySectionOffset;
}



// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	TripItinerary *it = [self getSafeItinerary:section];
	
	switch ([self sectionType:section])
	{
		case kSectionTypeEndPoints:
			return 4;
		case kSectionTypeOptions:
			if ([self legRows:it] > 0)
			{
				return [self legRows:it] + kRowAdditionalRows - ([it hasFare] ? 0 : 1) -1 + _smsRows + _calRows;
			}
			return 1;
		case kSectionRowDisclaimerType:
			if (self.tripQuery.reversed)
			{
				return 1;
			}
			return 2;
	}

	// Disclaimer row
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch ([self sectionType:section])
	{
	case kSectionTypeEndPoints:	
		return NSLocalizedString(@"The trip planner shows scheduled service only. Check below to see how detours may affect your trip.\n\nYour trip:", @"section header");
		break;
	case kSectionTypeOptions:
		{
			TripItinerary *it = [self getSafeItinerary:section];

			NSInteger legs = [self legRows:it];
	
			if (legs > 0)
			{
				return [NSString stringWithFormat:NSLocalizedString(@"Option %ld - %@", @"section header"), (long)(section + 1 - _itinerarySectionOffset), it.shortTravelTime];
			}
			else
			{
				return NSLocalizedString(@"No route was found:", @"section header");
			}
		}
	case kSectionRowDisclaimerType:
		// return @"Other options";
		break;
	}
	return nil;
}

- (void)populateTripCell:(TripItemCell *)cell itinerary:(TripItinerary *)it rowType:(NSInteger)rowType indexPath:(NSIndexPath*)indexPath
{

        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        switch (rowType)
    {
        case kRowTypeError:
            [cell populateBody:it.xmessage mode:@"No" time:@"Route" leftColor:nil route:nil];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            if (!self.tripQuery.gotData)
            {
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            
            // [cell populateBody:it.xmessage mode:nil time:nil];
            // cell.view.text = it.xmessage;
            break;
        case kRowTypeLeg:
        {
            TripLegEndPoint * ep = it.displayEndPoints[indexPath.row];
            [cell populateBody:ep.displayText mode:ep.displayModeText time:ep.displayTimeText leftColor:ep.leftColor
                         route:ep.xnumber];
            
            //[cell populateBody:@"l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l l"
            //                 mode:ep.displayModeText time:ep.displayTimeText leftColor:ep.leftColor
            //                route:ep.xnumber];
            
            
            if (ep.xstopId!=nil || ep.xlat !=nil)
            {
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                cell.accessoryType = KDisclosure;
            }
            else
            {
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
            // cell.view.text = [self getTextForLeg:indexPath];
            
            //printf("width: %f\n", cell.view.frame.size.width);
            break;
        case kRowTypeDuration:
            [cell populateBody:it.travelTime mode:@"Travel" time:@"time" leftColor:nil route:nil];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            // justText = [it getTravelTime];
            break;
        case kRowTypeFare:
            [cell populateBody:it.fare.stringWithTrailingSpacesRemoved
                          mode:@"Fare"
                          time:nil
                     leftColor:nil
                         route:nil];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            // justText = it.fare;
            break;
        case kRowTypeFrom:
            [cell populateBody:[self getFromText] mode:@"From" time:nil leftColor:nil route:nil];
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        case kRowTypeOptions:
            [cell populateBody:[self.tripQuery.userRequest optionsDisplayText] mode:@"Options" time:nil
                     leftColor:nil
                         route:nil];
            
            cell.accessibilityLabel = [self.tripQuery.userRequest optionsAccessability];
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            break;
        case kRowTypeTo:
            [cell populateBody:[self getToText] mode:@"To" time:nil leftColor:nil route:nil];
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
            
        case kRowTypeDateAndTime:
            
            
            [cell populateBody:[self.tripQuery.userRequest getDateAndTime]
                          mode:[self.tripQuery.userRequest getTimeType]
                          time:nil
                     leftColor:nil
                         route:nil];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.accessoryType = UITableViewCellAccessoryNone;
            break;
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	NSInteger rowType = [self rowType:indexPath];
	
	switch (rowType)
	{
		case kRowTypeError:
		case kRowTypeLeg:
		case kRowTypeDuration:
		case kRowTypeFare:
		case kRowTypeFrom:
		case kRowTypeTo:
		case kRowTypeDateAndTime:
		case kRowTypeOptions:
		{
			TripItinerary *it = [self getSafeItinerary:indexPath.section];
			TripItemCell *cell = [tableView dequeueReusableCellWithIdentifier:kTripItemCellId];
            [self populateTripCell:cell itinerary:it rowType:rowType indexPath:indexPath];
			return cell;
		}
		case kSectionRowDisclaimerType:
		{
			UITableViewCell *cell  = [tableView dequeueReusableCellWithIdentifier:kDisclaimerCellId];
			if (cell == nil) {
				cell = [self disclaimerCellWithReuseIdentifier:kDisclaimerCellId];
			}
		
			if (self.tripQuery.xdate != nil && self.tripQuery.xtime!=nil)
			{
				[self addTextToDisclaimerCell:cell text:[NSString stringWithFormat:@"Updated %@ %@", self.tripQuery.xdate, self.tripQuery.xtime]];
			}
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			return cell;
		}
		case kRowTypeMap:
		case kRowTypeEmail:
		case kRowTypeSMS:
		case kRowTypeCal:
		case kRowTypeClipboard:
		case kRowTypeReverse:
		case kRowTypeArrivals:
		case kRowTypeDetours:
        case kRowTypeAlarms:
		{
			static NSString *CellIdentifier = @"TripAction";
			
			UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
			if (cell == nil) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
			}	
			switch (rowType)
			{
				case kRowTypeDetours:
                    cell.textLabel.text = NSLocalizedString(@"Check detours", @"main menu item");
					cell.imageView.image = [self getActionIcon:kIconDetour];
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					break;
				case kRowTypeMap:
                    cell.textLabel.text = NSLocalizedString(@"Show on map", @"main menu item");
					cell.imageView.image = [self getActionIcon7:kIconMapAction7 old:kIconMapAction];
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					break;
				case kRowTypeEmail:
                    cell.textLabel.text = NSLocalizedString(@"Send by email", @"main menu item");
					cell.imageView.image = [self getActionIcon:kIconEmail];
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					break;
				case kRowTypeSMS:
                    cell.textLabel.text = NSLocalizedString(@"Send by text message", @"main menu item");
					cell.imageView.image = [self getActionIcon:kIconCell];
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					break;
				case kRowTypeCal:
                    cell.textLabel.text = NSLocalizedString(@"Add to calendar", @"main menu item");
					cell.imageView.image = [self getActionIcon:kIconCal];
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					break;
				case kRowTypeClipboard:
                    cell.textLabel.text = NSLocalizedString(@"Copy to clipboard", @"main menu item");
					cell.imageView.image = [self getActionIcon:kIconCut];
					cell.accessoryType = UITableViewCellAccessoryNone;
					break;
				case kRowTypeReverse:
                    cell.textLabel.text = NSLocalizedString(@"Reverse trip", @"main menu item");
					cell.imageView.image = [self getActionIcon:kIconReverse];
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					break;
				case kRowTypeArrivals:
                    cell.textLabel.text = NSLocalizedString(@"Arrivals for all stops", @"main menu item");
					cell.imageView.image = [self getActionIcon:kIconArrivals];
					cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    break;
                case kRowTypeAlarms:
                    cell.textLabel.text = NSLocalizedString(@"Set deboard alarms", @"main menu item");
                    cell.imageView.image = [self getActionIcon:kIconAlarm];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					break;
			}
			cell.textLabel.textColor = [ UIColor grayColor];
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			cell.textLabel.font = self.basicFont;
			[self updateAccessibility:cell indexPath:indexPath text:cell.textLabel.text alwaysSaySection:NO];
			return cell;
		}
	}
	
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSInteger rowType = [self rowType:indexPath];
	
	switch (rowType)
	{
        case kRowTypeError:
        case kRowTypeLeg:
        case kRowTypeDuration:
        case kRowTypeFare:
        case kRowTypeFrom:
        case kRowTypeTo:
        case kRowTypeDateAndTime:
        case kRowTypeOptions:
            return UITableViewAutomaticDimension;
		
		case kRowTypeEmail:
		case kRowTypeClipboard:
        case kRowTypeAlarms:
		case kRowTypeMap:
		case kRowTypeReverse:
		case kRowTypeArrivals:
		case kRowTypeSMS:
		case kRowTypeCal:
		case kRowTypeDetours:
			return [self basicRowHeight];
	}
	return kDisclaimerCellHeight;
}

- (NSString *)plainText:(TripItinerary *)it
{
	NSMutableString *trip = [NSMutableString string];
	
//	TripItinerary *it = [self getSafeItinerary:indexPath.section];
	
	if (self.tripQuery.resultFrom != nil)
	{
		[trip appendFormat:@"From: %@\n",
		 self.tripQuery.resultFrom.xdescription
		 ];
	}
	
	if (self.tripQuery.resultTo != nil)
	{
		[trip appendFormat:@"To: %@\n",
		 self.tripQuery.resultTo.xdescription
		 ];
	}
	

	[trip appendFormat:@"%@: %@\n\n", [self.tripQuery.userRequest getTimeType], [self.tripQuery.userRequest getDateAndTime]];
	
	/*
	 [trip appendFormat:@"Max walk: %0.1f miles<br>Travel by: %@<br>Show the: %@<br><br>", self.tripQuery.walk,
	 [self.tripQuery getMode], [self.tripQuery getMin]];
	 */
	
	NSString *htmlText = [it startPointText:TripTextTypeClip];
	[trip appendString:htmlText];
	
	int i;
	for (i=0; i< [it legCount]; i++)
	{
		TripLeg *leg = [it getLeg:i];
		htmlText = [leg createFromText:(i==0) textType:TripTextTypeClip];
		[trip appendString:htmlText];
		htmlText = [leg createToText:(i==[it legCount]-1) textType:TripTextTypeClip];
		[trip appendString:htmlText];
	}
	
	[trip appendFormat:@"Scheduled travel time: %@\n\n",it.travelTime];
	
	if (it.fare != nil)
	{
		[trip appendFormat:@"Fare: %@",it.fare ];
	}
	
	return trip;
}

-(void)addCalendarItem:(EKEventStore *)eventStore
{
    if (eventStore==nil)
    {
        eventStore = [[[EKEventStore alloc] init] autorelease];
    }
    
    EKEvent *event  = [EKEvent eventWithEventStore:eventStore];
    event.title     = [NSString stringWithFormat:@"TriMet Trip\n%@", [self.tripQuery mediumName]];
    event.notes     = [NSString stringWithFormat:@"Note: ensure you leave early enough to arrive in time for the first connection.\n\n%@"
                       "\nRoute and arrival data provided by permission of TriMet.",
                       [self plainText:self.calendarItinerary]];
    
    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    NSLocale *enUS = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease];
    dateFormatter.locale = enUS;
    
    
    // Yikes - may have AM or PM or be 12 hour. :-(
    unichar last = [self.calendarItinerary.xstartTime characterAtIndex:(self.calendarItinerary.xstartTime.length-1)];
    if (last=='M' || last=='m')
    {
        dateFormatter.dateFormat = @"M/d/yy hh:mm a";
    }
    else
    {
        dateFormatter.dateFormat = @"M/d/yy HH:mm:ss";
    }
    
    dateFormatter.timeZone = [NSTimeZone localTimeZone];
    
    NSString *fullDateStr = [NSString stringWithFormat:@"%@ %@", self.calendarItinerary.xdate, self.calendarItinerary.xstartTime];
    NSDate *start = [dateFormatter dateFromString:fullDateStr];
    
    
    
    // The start time does not include the inital walk so take it off...
    for (int i=0; i< [self.calendarItinerary legCount]; i++)
    {
        TripLeg *leg = [self.calendarItinerary getLeg:i];
        
        if (leg.mode == nil)
        {
            continue;
        }
        if ([leg.mode isEqualToString:kModeWalk])
        {
#ifdef ORIGINAL_IPHONE
            start = [start addTimeInterval: -([leg.xduration intValue] * 60)];
#else
            start = [start dateByAddingTimeInterval: -(leg.xduration.intValue * 60)];;
#endif
            
            
        }
        else {
            break;
        }
    }
#ifdef ORIGINAL_IPHONE
    NSDate *end   = [start addTimeInterval: [self.calendarItinerary.xduration intValue] * 60];
#else
    NSDate *end   = [start dateByAddingTimeInterval: self.calendarItinerary.xduration.intValue * 60];
#endif
    
    
    event.startDate = start;
    event.endDate   = end;
    
    EKCalendar *cal = eventStore.defaultCalendarForNewEvents;
    
    event.calendar = cal;
    NSError *err;
    if (cal !=nil && [eventStore saveEvent:event span:EKSpanThisEvent error:&err])
    {
        // Upon selecting an event, create an EKEventViewController to display the event.
        EKEventViewController *detailViewController = [[EKEventViewController alloc] initWithNibName:nil bundle:nil];
        detailViewController.event = event;
        detailViewController.title = NSLocalizedString(@"Calendar Event", @"page title");
        
        // Allow event editing.
        detailViewController.allowsEditing = YES;
        
        //	Push detailViewController onto the navigation controller stack
        //	If the underlying event gets deleted, detailViewController will remove itself from
        //	the stack and clear its event property.
        [self.navigationController pushViewController:detailViewController animated:YES];
        [detailViewController release];
    }
}
	
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;
{
    if (_alarmItem != kNoBookmark)
    {
        TripItinerary *it = [self getSafeItinerary:_alarmItem];
        AlarmTaskList *taskList = [AlarmTaskList sharedInstance];
        
        for (TripLegEndPoint *leg in it.displayEndPoints)
        {
            if (leg.deboard)
            {
                if (![taskList hasTaskForStopIdProximity:leg.stopId])
                {
                    [taskList userAlertForProximityAction:(int)buttonIndex stopId:leg.xstopId loc:leg.loc desc:leg.xdescription];
                }
            }
        }
        _alarmItem = kNoBookmark;
    }
    else if (buttonIndex == 0)
	{
		NSIndexPath *ip = self.table.indexPathForSelectedRow;
		if (ip!=nil)
		{
			[self.table deselectRowAtIndexPath:ip animated:YES];
		}
	}
	else
    {
        [self addCalendarItem:nil];
    }
		
}

- (void)calendarAlert:(NSNumber *)grantedObject
{
    bool granted = grantedObject.boolValue;
    
    if (granted)
    {
        // [self addCalendarItem:nil];
        UIAlertView *alert = [[[ UIAlertView alloc ] initWithTitle:NSLocalizedString(@"Calendar", @"alert title")
                                                           message:NSLocalizedString(@"Are you sure you want to add this to your default calendar?", @"alert message")
                                                          delegate:self
                                                 cancelButtonTitle:NSLocalizedString(@"No", @"button text")
                                                 otherButtonTitles:NSLocalizedString(@"Yes", @"button text"), nil ] autorelease];
        [alert show];
    }
    else
    {
        UIAlertView *alert = [[[ UIAlertView alloc ] initWithTitle:NSLocalizedString(@"Calendar", @"alert title")
                                                           message:NSLocalizedString(@"Calendar access has been denied. Please check the app settings to allow access to the calendar.",  @"alert message")
                                                          delegate:self
                                                 cancelButtonTitle:NSLocalizedString(@"No", @"button text")
                                                 otherButtonTitles:nil ] autorelease];
        [alert show];
    }
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
	// AnotherViewController *anotherViewController = [[AnotherViewController alloc] initWithNibName:@"AnotherView" bundle:nil];
	// [self.navigationController pushViewController:anotherViewController];
	// [anotherViewController release];
	switch ([self rowType:indexPath])
	{
		case kRowTypeError:
			if (!self.tripQuery.gotData)
			{
				
				[self networkTips:self.tripQuery.htmlError networkError:self.tripQuery.errorMsg];
                [self clearSelection];
				
			}
			break;
		case kRowTypeTo:
		case kRowTypeFrom:
		{
			TripLegEndPoint *ep = nil;
			
			if ([self rowType:indexPath] == kRowTypeTo)
			{
				ep = self.tripQuery.resultTo;
			}
			else
			{
				ep = self.tripQuery.resultFrom;
			}
			
			[self selectLeg:ep];
			break;
		}
			
		case kRowTypeLeg:
			{
				TripItinerary *it = [self getSafeItinerary:indexPath.section];
				TripLegEndPoint *leg = it.displayEndPoints[indexPath.row];
				[self selectLeg:leg];
			}
			
			break;
		case kRowTypeDuration:
		case kSectionRowDisclaimerType:
		case kRowTypeFare:
			break;
		case kRowTypeClipboard:
		{
			TripItinerary *it = [self getSafeItinerary:indexPath.section];
			[self.table deselectRowAtIndexPath:indexPath animated:YES];
			UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
			pasteboard.string = [self plainText:it];
			break;
		}
        case kRowTypeAlarms:
        {
            AlarmTaskList *taskList = [AlarmTaskList sharedInstance];
            
            if ([LocationAuthorization locationAuthorizedOrNotDeterminedShowMsg:NO backgroundRequired:YES])
            {
                _alarmItem = (int)indexPath.section;
                [taskList userAlertForProximity:self];
            }
            else
            {
                [LocationAuthorization locationAuthorizedOrNotDeterminedShowMsg:YES backgroundRequired:YES];
            }
            [self.table deselectRowAtIndexPath:indexPath animated:YES];
            break;
            
        }
		case kRowTypeSMS:
		{
			TripItinerary *it = [self getSafeItinerary:indexPath.section];
			MFMessageComposeViewController *picker = [[MFMessageComposeViewController alloc] init];
			picker.messageComposeDelegate = self;
			
			picker.body = [self plainText:it];
			
			[self presentViewController:picker animated:YES completion:nil];
			[picker release];
			break;
		}
		case kRowTypeCal:
		{
			self.calendarItinerary = [self getSafeItinerary:indexPath.section];
            
            EKEventStore *eventStore = [[[EKEventStore alloc] init] autorelease];
            
            // maybe check for access
            [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
                
                [self performSelectorOnMainThread:@selector(calendarAlert:) withObject:@(granted) waitUntilDone:FALSE];
                
            }];
            
	
		}
		break;
		case kRowTypeEmail:
		{
			
			
			NSMutableString *trip = [[NSMutableString alloc] init];
			
			TripItinerary *it = [self getSafeItinerary:indexPath.section];
			
			if (self.tripQuery.resultFrom != nil)
			{
				if (self.tripQuery.resultFrom.xlat!=nil)
				{
					[trip appendFormat:@"From: <a href=\"http://map.google.com/?q=location@%@,%@\">%@<br></a>",
							self.tripQuery.resultFrom.xlat, self.tripQuery.resultFrom.xlon,
							self.tripQuery.resultFrom.xdescription
					 ];
				}
				else
				{
					[trip appendFormat:@"%@<br>", [self getFromText]];
				}
			}
		
			if (self.tripQuery.resultTo != nil)
			{
				if (self.tripQuery.resultTo.xlat)
				{
					[trip appendFormat:@"To: <a href=\"http://map.google.com/?q=location@%@,%@\">%@<br></a>",
					 self.tripQuery.resultTo.xlat, self.tripQuery.resultTo.xlon,
					 self.tripQuery.resultTo.xdescription
					 ];
				}
				else
				{
					[trip appendFormat:@"%@<br>", [self getToText]];
				}
			}
			
			[trip appendFormat:@"%@:%@<br><br>", [self.tripQuery.userRequest getTimeType], [self.tripQuery.userRequest getDateAndTime]];
			
			/*
			[trip appendFormat:@"Max walk: %0.1f miles<br>Travel by: %@<br>Show the: %@<br><br>", self.tripQuery.walk,
					[self.tripQuery getMode], [self.tripQuery getMin]];
			 */
			
			NSString *htmlText = [it startPointText:TripTextTypeHTML];
			[trip appendString:htmlText];
			
			int i;
			for (i=0; i< [it legCount]; i++)
			{
				TripLeg *leg = [it getLeg:i];
				htmlText = [leg createFromText:(i==0) textType:TripTextTypeHTML];
				[trip appendString:htmlText];
				htmlText = [leg createToText:(i==[it legCount]-1) textType:TripTextTypeHTML];
				[trip appendString:htmlText];
			}
			
			[trip appendFormat:@"Travel time: %@<br><br>",it.travelTime];
			
			if (it.fare != nil)
			{
				[trip appendFormat:@"Fare: %@<br><br>",it.fare ];
			}
			
			MFMailComposeViewController *email = [[MFMailComposeViewController alloc] init];
			
			email.mailComposeDelegate = self;
			
			if (![MFMailComposeViewController canSendMail])
			{
				UIAlertView *alert = [[[ UIAlertView alloc ] initWithTitle:NSLocalizedString(@"email", @"alert title")
																   message:NSLocalizedString(@"Cannot send email on this device", @"alert message")
																  delegate:nil
														 cancelButtonTitle:NSLocalizedString(@"OK", @"button text")
														 otherButtonTitles:nil] autorelease];
				[alert show];
				[email release];
				[trip release];
				break;
			}
			
			[email setSubject:@"TriMet Trip"];
			
			[email setMessageBody:trip isHTML:YES];
			
			[self presentViewController:email animated:YES completion:nil];
			[email release];

			
			[trip release];
		}
		break;
		case kRowTypeMap:
		{
            TripPlannerMap *mapPage = [TripPlannerMap viewController];
			mapPage.callback = self.callback;
			mapPage.lines = YES;
			TripItinerary *it = [self getSafeItinerary:indexPath.section];
	
			int i,j = 0;
			for (i=0; i< [it legCount]; i++)
			{
				TripLeg *leg = [it getLeg:i];
				[leg createFromText:(i==0) textType:TripTextTypeMap];
				
				if (leg.from.mapText != nil)
				{
					j++;
					leg.from.index = j;
					
					[mapPage addPin:leg.from];
				}
				
				[leg createToText:(i==([it legCount]-1)) textType:TripTextTypeMap];
				if (leg.to.mapText != nil)
				{
					j++;
					leg.to.index = j;
					
					[mapPage addPin:leg.to];
				}
				
			}
			
			mapPage.it = it;
			
            [mapPage fetchShapesAsync:self.backgroundTask];
		}
		break;
		case kRowTypeReverse:
		{
			XMLTrips * reverse = [self.tripQuery createReverse];
			
            TripPlannerDateView *tripDate = [TripPlannerDateView viewController];
			
			tripDate.userFaves = reverse.userFaves;
			tripDate.tripQuery = reverse;
			
			// Push the detail view controller
			[tripDate nextScreen:self.navigationController taskContainer:self.backgroundTask];
			/*
			 TripPlannerEndPointView *tripStart = [[TripPlannerEndPointView alloc] init];
			 
			 // Push the detail view controller
			 [self.navigationController pushViewController:tripStart animated:YES];
			 [tripStart release];
			 */
			break;
			
		}
		case kRowTypeDetours:
		{
            NSMutableArray *allRoutes = [NSMutableArray array];
			NSString *route = nil;
            NSMutableSet *allRoutesSet = [NSMutableSet set];
			
			TripItinerary *it = [self getSafeItinerary:indexPath.section];
			
			
			int i = 0;
			for (i=0; i< [it legCount]; i++)
			{
				TripLeg *leg = [it getLeg:i];
				
				route = leg.xinternalNumber;
				
				if (route && ![allRoutesSet containsObject:route])
				{
					[allRoutesSet addObject:route];
					
					[allRoutes addObject:route];
				}
				
			}
			
			if (allRoutes.count >0 )
			{
				[[DetoursView viewController] fetchDetoursAsync:self.backgroundTask routes:allRoutes];
			}
			break;
		}
		case kRowTypeArrivals:
		{
			NSMutableString *allstops = [NSMutableString string];
			NSString *lastStop = nil;
			NSString *nextStop = nil;
			
			TripItinerary *it = [self getSafeItinerary:indexPath.section];
			
			
			int i = 0;
			int j = 0;
			for (i=0; i< [it legCount]; i++)
			{
				TripLeg *leg = [it getLeg:i];
				
				nextStop = [leg.from stopId];
				
				for (j=0; j<2; j++)
				{
					if (nextStop !=nil && (lastStop==nil || ![nextStop isEqualToString:lastStop]))
					{
						if (allstops.length > 0)
						{
							[allstops appendFormat:@","];
						}
						[allstops appendFormat:@"%@", nextStop];
						lastStop = nextStop;
					}
					nextStop = [leg.to stopId];
				}
			}
			
			if (allstops.length >0 )
			{
				[[DepartureTimesView viewController] fetchTimesForLocationAsync:self.backgroundTask loc:allstops];
			}
			break;
		}
			
	}
}

#pragma mark Mail composer delegate

// Dismisses the email composition interface when users tap Cancel or Send. Proceeds to update the message field with the result of the operation.
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error 
{	
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark SMS composer delegate

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -
#pragma mark EKEventEditViewDelegate

// Overriding EKEventEditViewDelegate method to update event store according to user actions.
- (void)eventEditViewController:(EKEventEditViewController *)controller 
		  didCompleteWithAction:(EKEventEditViewAction)action {
	
	NSError *error = nil;
	EKEvent *thisEvent = controller.event;
	
	switch (action) {
		case EKEventEditViewActionCanceled:
			// Edit action canceled, do nothing. 
			break;
			
		case EKEventEditViewActionSaved:
			[controller.eventStore saveEvent:controller.event span:EKSpanThisEvent error:&error];
			break;
			
		case EKEventEditViewActionDeleted:
			[controller.eventStore removeEvent:thisEvent span:EKSpanThisEvent error:&error];
			break;
			
		default:
			break;
	}
	// Dismiss the modal view controller
	[controller dismissViewControllerAnimated:YES completion:nil];
	
}

- (void) viewWillDisappear:(BOOL)animated
{
    if (self.userActivity!=nil)
    {
        [self.userActivity invalidate];
        self.userActivity = nil;
    }
    
    [super viewWillDisappear:animated];
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    Class userActivityClass = (NSClassFromString(@"NSUserActivity"));
    
    if (userActivityClass !=nil)
    {
        
        if (self.userActivity != nil)
        {
            [self.userActivity invalidate];
            self.userActivity = nil;
        }
        
        NSDictionary *tripItem = [self.tripQuery.userRequest toDictionary];
        
        [tripItem setValue:@"yes" forKey:kDictUserRequestHistorical];
        
        if (tripItem)
        {
            self.userActivity = [[[NSUserActivity alloc] initWithActivityType:kHandoffUserActivityBookmark] autorelease];
            NSMutableDictionary *info = [NSMutableDictionary dictionary];
            
            info[kUserFavesTrip] = tripItem;
            
           //  [info setObject:tripItem forKey:kUserFavesTrip];
            self.userActivity.userInfo = info;
            [self.userActivity becomeCurrent];
        }
        
    }
    
}





@end

