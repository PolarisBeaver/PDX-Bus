//
//  NetworkTestView.m
//  PDX Bus
//
//  Created by Andrew Wallace on 8/25/09.
//



/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */


#import "NetworkTestView.h"
#import "XMLDetours.h"
#import "XMLTrips.h"
#import "XMLStreetcarLocations.h"
#import "ReverseGeoLocator.h"
#import "UITableViewCell+MultiLineCell.h"

@implementation NetworkTestView

@synthesize trimetQueryStatus			= _trimetQueryStatus;
@synthesize nextbusQueryStatus			= _nextbusQueryStatus;
@synthesize internetConnectionStatus	= _internetConnectionStatus;
@synthesize diagnosticText				= _diagnosticText;
@synthesize reverseGeoCodeService		= _reverseGeoCodeService;
@synthesize reverseGeoCodeStatus		= _reverseGeoCodeStatus;
@synthesize trimetTripStatus			= _trimetTripStatus;
@synthesize networkErrorFromQuery		= _networkErrorFromQuery;

#define KSectionMaybeError		0
#define kSectionInternet		1
#define kSectionTriMet			2
#define kSectionTriMetTrip		3
#define kSectionNextBus			4
#define kSectionReverseGeoCode	5
#define kSectionDiagnose		6
#define kSections				7
#define kNoErrorSections		6

- (void)dealloc {
	self.diagnosticText			= nil;
	self.reverseGeoCodeService	= nil;
	self.networkErrorFromQuery	= nil;
    [super dealloc];
}

#pragma mark Data fetchers

- (void)fetchNetworkStatusAsync:(id<BackgroundTaskProgress>)background
{
	self.backgroundTask.callbackWhenFetching = background;
    
    [self runAsyncOnBackgroundThread:^{
        
        [self.backgroundTask.callbackWhenFetching backgroundStart:5 title:@"checking network"];
        
        self.internetConnectionStatus = [TriMetXML isDataSourceAvailable:YES];
        
        [self.backgroundTask.callbackWhenFetching backgroundItemsDone:1];
        
        XMLDetours *detours = [XMLDetours xml];
        
        detours.giveUp = 7;
        
        [detours getDetours];
        
        self.trimetQueryStatus = detours.gotData;
        
        
        [self.backgroundTask.callbackWhenFetching backgroundItemsDone:2];
        
        XMLTrips *trips = [XMLTrips xml];
        trips.userRequest.dateAndTime = nil;
        trips.userRequest.arrivalTime = NO;
        trips.userRequest.timeChoice  = TripDepartAfterTime;
        trips.userRequest.toPoint.locationDesc   = @"8336"; // Yamhil District
        trips.userRequest.fromPoint.locationDesc = @"8334"; // Pioneer Square South
        trips.giveUp = 7;
        
        [trips fetchItineraries:nil];
        
        self.trimetTripStatus = trips.gotData;
        
        [self.backgroundTask.callbackWhenFetching backgroundItemsDone:3];
        
        XMLStreetcarLocations *locations = [XMLStreetcarLocations autoSingletonForRoute:@"streetcar"];
        
        locations.giveUp = 7;
        
        [locations getLocations];
    
        self.nextbusQueryStatus = locations.gotData;
        
        [self.backgroundTask.callbackWhenFetching backgroundItemsDone:4];
        
        if ([ReverseGeoLocator supported])
        {
            
            ReverseGeoLocator *provider = [[[ReverseGeoLocator alloc] init] autorelease];
            // Pioneer Square!
            
            CLLocation *loc = [[[CLLocation alloc] initWithLatitude:45.519077 longitude:-122.678602] autorelease];
            [provider fetchAddress:loc];
            self.reverseGeoCodeStatus = (provider.error == nil);
            self.reverseGeoCodeService = @"Apple Geocoder";
        }
        else {
            self.reverseGeoCodeService = nil;
            self.reverseGeoCodeStatus = YES;
        }
        
        [self.backgroundTask.callbackWhenFetching backgroundItemsDone:5];
        
        NSMutableString *diagnosticString = [NSMutableString string];
        
        if (!self.internetConnectionStatus)
        {
            [diagnosticString appendString:@"The Internet is not available. Check you are not in Airplane mode, and not in the Robertson Tunnel.\n\nIf your device is capable, you could also try switching between WiFi, Edge and 3G.\n\nTouch here to start Safari to check your connection. "];
        }
        else if (!self.trimetQueryStatus || !self.nextbusQueryStatus || !self.trimetTripStatus)
        {
            [diagnosticString appendString:@"The Internet is available, but PDX Bus is not able to contact TriMet's or NextBus's servers. Touch here to check if www.trimet.org is working."];
        }
        else
        {
            [diagnosticString appendString:@"The main network services are working at this time. If you are having problems, touch here to load www.trimet.org, then restart PDX Bus."];
        }
        
        if (self.internetConnectionStatus && !self.reverseGeoCodeStatus && self.reverseGeoCodeService!=nil)
        {
            
            [diagnosticString appendFormat:@"\n\nApple's GeoCoding service is not responding."];
        }
        
        self.diagnosticText = diagnosticString;
        
        [self.backgroundTask.callbackWhenFetching backgroundCompleted:self];
    }];
}

#pragma mark View Methods

- (instancetype)init {
	if ((self = [super init]))
	{
        self.title = NSLocalizedString(@"Network", @"page title");
	}
	return self;
}

- (NSInteger)adjustSectionNumber:(NSInteger)section
{
	if (self.networkErrorFromQuery==nil)
	{
		return section+1;
	}
	return section;
}

/*
 - (id)initWithStyle:(UITableViewStyle)style {
 // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
 if (self = [super initWithStyle:style]) {
 }
 return self;
 }
 */

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    // add our custom add button as the nav bar's custom right view
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc]
                                      initWithTitle:NSLocalizedString(@"Refresh", @"")
                                      style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(refreshAction:)];
    self.navigationItem.rightBarButtonItem = refreshButton;
    [refreshButton release];
    
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}


/*
 - (void)viewWillAppear:(BOOL)animated {
 [super viewWillAppear:animated];
 }
 */
/*
 - (void)viewDidAppear:(BOOL)animated {
 [super viewDidAppear:animated];
 }
 */
/*
 - (void)viewWillDisappear:(BOOL)animated {
 [super viewWillDisappear:animated];
 }
 */
/*
 - (void)viewDidDisappear:(BOOL)animated {
 [super viewDidDisappear:animated];
 }
 */

/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */



- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

#pragma mark Helper functions

- (void)refreshAction:(id)sender
{
	self.backgroundRefresh		= YES;
	self.networkErrorFromQuery	= nil;
	[self fetchNetworkStatusAsync:self.backgroundTask];
}

- (UITableViewStyle) getStyle
{
	return UITableViewStyleGrouped;
}

- (UITableViewCell *)networkStatusCell
{
    UITableViewCell *cell = [self.table dequeueReusableCellWithIdentifier:MakeCellId(networkStatusCell)];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MakeCellId(networkStatusCell)] autorelease];
	}
	
	// Set up the cell...
	cell.textLabel.adjustsFontSizeToFitWidth = YES;
	cell.textLabel.textAlignment = NSTextAlignmentCenter;
	cell.textLabel.font = self.basicFont;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}


#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if (self.networkErrorFromQuery==nil)
	{
		return kNoErrorSections;
	}
    return kSections;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = nil;

	switch ([self adjustSectionNumber:indexPath.section])
	{
        default:
		case kSectionInternet:
			cell = [self networkStatusCell];
			
			if (!self.internetConnectionStatus)
			{
                cell.textLabel.text = NSLocalizedString(@"Not able to access the Internet", @"network error");
				cell.textLabel.textColor = [UIColor redColor];
				cell.imageView.image = [TableViewWithToolbar alwaysGetIcon:kIconNetworkBad];
				cell.textLabel.font = self.basicFont;
			}
			else
			{
				cell.textLabel.text = NSLocalizedString(@"Internet access is available", @"network error");
				cell.imageView.image = [TableViewWithToolbar alwaysGetIcon:kIconNetworkOk];
				cell.textLabel.textColor = [UIColor blackColor];
				cell.textLabel.font = self.basicFont;
			}
			break;
		case kSectionTriMet:
			cell = [self networkStatusCell];
			
			if (!self.trimetQueryStatus)
			{
                cell.textLabel.text = NSLocalizedString(@"Not able to access TriMet arrival servers", @"network error");
				cell.textLabel.textColor = [UIColor redColor];
				cell.imageView.image = [TableViewWithToolbar alwaysGetIcon:kIconNetworkBad];
				cell.textLabel.font = self.basicFont;
			}
			else
			{
                cell.textLabel.text = NSLocalizedString(@"TriMet arrival servers are available", @"network errror");
				cell.textLabel.textColor = [UIColor blackColor];
				cell.imageView.image = [TableViewWithToolbar alwaysGetIcon:kIconNetworkOk];
				cell.textLabel.font = self.basicFont;
			}
			break;
		case kSectionTriMetTrip:
			cell = [self networkStatusCell];
			
			if (!self.trimetTripStatus)
			{
				cell.textLabel.text = NSLocalizedString(@"Not able to access TriMet trip servers", @"network errror");
				cell.textLabel.textColor = [UIColor redColor];
				cell.imageView.image = [TableViewWithToolbar alwaysGetIcon:kIconNetworkBad];
				cell.textLabel.font = self.basicFont;
			}
			else
			{
                cell.textLabel.text = NSLocalizedString(@"TriMet trip servers are available", @"network errror");

				cell.textLabel.textColor = [UIColor blackColor];
				cell.imageView.image = [TableViewWithToolbar alwaysGetIcon:kIconNetworkOk];
				cell.textLabel.font = self.basicFont;
			}
			break;
		case kSectionNextBus:
			cell = [self networkStatusCell];
			
			if (!self.nextbusQueryStatus)
			{
				cell.textLabel.text = NSLocalizedString(@"Not able to access NextBus (Streetcar) servers", @"network errror");
				cell.textLabel.textColor = [UIColor redColor];
				cell.imageView.image = [TableViewWithToolbar alwaysGetIcon:kIconNetworkBad];
				cell.textLabel.font = self.basicFont;
			}
			else
			{
                cell.textLabel.text = NSLocalizedString(@"NextBus (Streetcar) servers are available", @"network errror");
				cell.textLabel.textColor = [UIColor blackColor];
				cell.imageView.image = [TableViewWithToolbar alwaysGetIcon:kIconNetworkOk];
				cell.textLabel.font = self.basicFont;
			}
			break;
		case kSectionReverseGeoCode:
			cell = [self networkStatusCell];
			
			if (self.reverseGeoCodeService == nil)
			{
				cell.textLabel.text = NSLocalizedString(@"No Reverse GeoCoding service is not supported.", @"network errror");
				cell.textLabel.textColor = [UIColor grayColor];
				cell.imageView.image = [TableViewWithToolbar alwaysGetIcon:kIconNetworkOk];
				cell.textLabel.font = self.basicFont;
			}
			else  if (!self.reverseGeoCodeStatus)
			{
				cell.textLabel.text = NSLocalizedString(@"Not able to access Apple's Geocoding servers.", @"network errror");
				cell.textLabel.textColor = [UIColor redColor];
				cell.imageView.image = [TableViewWithToolbar alwaysGetIcon:kIconNetworkBad];
				cell.textLabel.font = self.basicFont;
			}
			else
			{
				cell.textLabel.text = NSLocalizedString(@"Apple's Geocoding servers are available.", @"network errror");
				cell.textLabel.textColor = [UIColor blackColor];
				cell.imageView.image = [TableViewWithToolbar alwaysGetIcon:kIconNetworkOk];
				cell.textLabel.font = self.basicFont;
			}
			break;
		case kSectionDiagnose:
		{
			static NSString *diagsId = @"diags";
			cell = [tableView dequeueReusableCellWithIdentifier:diagsId];
			if (cell == nil) {
                cell = [UITableViewCell cellWithMultipleLines:diagsId font:self.paragraphFont];
			}
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.textLabel.text = self.diagnosticText;
			break;
		}
		case KSectionMaybeError:
		{
			static NSString *diagsId = @"error";
			cell = [tableView dequeueReusableCellWithIdentifier:diagsId];
			if (cell == nil) {
				cell = [UITableViewCell cellWithMultipleLines:diagsId font:self.paragraphFont];

			}
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.textLabel.text = self.networkErrorFromQuery;
			break;
		}
            break;
	}
	
    return cell;

}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	switch ([self adjustSectionNumber:indexPath.section]) {
		case KSectionMaybeError:
        case kSectionDiagnose:
            return UITableViewAutomaticDimension;
		default:
			return [self basicRowHeight];
	}
	return [self basicRowHeight];
	
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self adjustSectionNumber:indexPath.section] == kSectionDiagnose)
	{
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.trimet.org"]];
	}
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if ([self adjustSectionNumber:section] == KSectionMaybeError)
	{
        return NSLocalizedString(@"There was a network problem:", @"section title");
	}
	return nil;
}


/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */


/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
 }
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */


/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */


/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */



@end

