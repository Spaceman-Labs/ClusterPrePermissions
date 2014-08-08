//
//  ClusterPrePermissions.m
//  ClusterPrePermissions
//
//  Created by Rizwan Sattar on 4/7/14.
//  Copyright (c) 2014 Cluster Labs, Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#import "ClusterPrePermissions.h"

@import AddressBook;
@import AssetsLibrary;
@import CoreLocation;
@import EventKit;

NSString * const clusterPrePermissionsWillDisplayPrePermissionRequest = @"clusterPrePermissionsWillDisplayPrePermissionRequest";
NSString * const clusterPrePermissionsDidDisplayPrePermissionRequest = @"clusterPrePermissionsDidDisplayPrePermissionRequest";
NSString * const clusterPrePermissionsWillDisplayPermissionRequest = @"clusterPrePermissionsWillDisplayPermissionRequest";
NSString * const clusterPrePermissionsDidDisplayPermissionRequest = @"clusterPrePermissionsDidDisplayPermissionRequest";

NSString * const clusterPermissionTypeKey = @"clusterPermissionTypeKey";

NSString * const clusterPermissionTypePhoto = @"clusterPermissionTypePhoto";
NSString * const clusterPermissionTypeContacts = @"clusterPermissionTypeContacts";
NSString * const clusterPermissionTypeLocation = @"clusterPermissionTypeLocation";
NSString * const clusterPermissionTypeCalendar = @"clusterPermissionTypeCalendar";


@interface ClusterPrePermissions () <UIAlertViewDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIAlertView *prePhotoPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler photoPermissionCompletionHandler;

@property (strong, nonatomic) UIAlertView *preContactPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler contactPermissionCompletionHandler;

@property (strong, nonatomic) UIAlertView *preLocationPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler locationPermissionCompletionHandler;
@property (strong, nonatomic) CLLocationManager *locationManager;

@property (strong, nonatomic) UIAlertView *preCalendarPermissionAlertView;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler calendarPermissionCompletionHandler;
@property (strong, nonatomic) EKEventStore *eventStore;
@property (assign, nonatomic) EKEntityType eventEntityType;

@end

static ClusterPrePermissions *__sharedInstance;

@implementation ClusterPrePermissions

+ (instancetype) sharedPermissions
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[ClusterPrePermissions alloc] init];
    });
    return __sharedInstance;
}


#pragma mark - Photo Permissions Help

- (void) showPhotoPermissionsWithTitle:(NSString *)requestTitle
                               message:(NSString *)message
                       denyButtonTitle:(NSString *)denyButtonTitle
                      grantButtonTitle:(NSString *)grantButtonTitle
                     completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Photos?";
    }
    if (denyButtonTitle.length == 0) {
        denyButtonTitle = @"Not Now";
    }
    if (grantButtonTitle.length == 0) {
        grantButtonTitle = @"Give Access";
    }
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    if (status == ALAuthorizationStatusNotDetermined) {
		
		[self postWillDisplayPrePermissions:clusterPermissionTypePhoto];
        self.photoPermissionCompletionHandler = completionHandler;
        self.prePhotoPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                      message:message
                                                                     delegate:self
                                                            cancelButtonTitle:denyButtonTitle
                                                            otherButtonTitles:grantButtonTitle, nil];
        [self.prePhotoPermissionAlertView show];
    } else {
        if (completionHandler) {
            completionHandler((status == ALAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualPhotoPermissionAlert
{
	[self postWillDisplayPermissions:clusterPermissionTypePhoto];
	
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        // Got access! Show login
        [self firePhotoPermissionCompletionHandler];
        *stop = YES;
    } failureBlock:^(NSError *error) {
        // User denied access
        [self firePhotoPermissionCompletionHandler];
    }];
}


- (void) firePhotoPermissionCompletionHandler
{
	[self postDidDisplayPermissions:clusterPermissionTypePhoto];
	
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    if (self.photoPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == ALAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == ALAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == ALAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == ALAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.photoPermissionCompletionHandler((status == ALAuthorizationStatusAuthorized),
                                              userDialogResult,
                                              systemDialogResult);
        self.photoPermissionCompletionHandler = nil;
    }
}


#pragma mark - Contact Permissions Help


- (void) showContactsPermissionsWithTitle:(NSString *)requestTitle
                                  message:(NSString *)message
                          denyButtonTitle:(NSString *)denyButtonTitle
                         grantButtonTitle:(NSString *)grantButtonTitle
                        completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Contacts?";
    }
    if (denyButtonTitle.length == 0) {
        denyButtonTitle = @"Not Now";
    }
    if (grantButtonTitle.length == 0) {
        grantButtonTitle = @"Give Access";
    }
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    if (status == kABAuthorizationStatusNotDetermined) {
		[self postWillDisplayPrePermissions:clusterPermissionTypeContacts];
        self.contactPermissionCompletionHandler = completionHandler;
        self.preContactPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                        message:message
                                                                       delegate:self
                                                              cancelButtonTitle:denyButtonTitle
                                                              otherButtonTitles:grantButtonTitle, nil];
        [self.preContactPermissionAlertView show];
    } else {
        if (completionHandler) {
            completionHandler((status == kABAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualContactPermissionAlert
{
	[self postWillDisplayPermissions:clusterPermissionTypeContacts];
	
    CFErrorRef error = nil;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, &error);
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fireContactPermissionCompletionHandler];
        });
    });
}


- (void) fireContactPermissionCompletionHandler
{
	[self postDidDisplayPermissions:clusterPermissionTypeContacts];
	
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    if (self.contactPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == kABAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == kABAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == kABAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == kABAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.contactPermissionCompletionHandler((status == kABAuthorizationStatusAuthorized),
                                                userDialogResult,
                                                systemDialogResult);
        self.contactPermissionCompletionHandler = nil;
    }
}


#pragma mark - Location Permission Help


- (void) showLocationPermissionsWithTitle:(NSString *)requestTitle
                                  message:(NSString *)message
                          denyButtonTitle:(NSString *)denyButtonTitle
                         grantButtonTitle:(NSString *)grantButtonTitle
                        completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Location?";
    }
    if (denyButtonTitle.length == 0) {
        denyButtonTitle = @"Not Now";
    }
    if (grantButtonTitle.length == 0) {
        grantButtonTitle = @"Give Access";
    }
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined) {
		[self postWillDisplayPrePermissions:clusterPermissionTypeLocation];
		
        self.locationPermissionCompletionHandler = completionHandler;
        self.preLocationPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                         message:message
                                                                        delegate:self
                                                               cancelButtonTitle:denyButtonTitle
                                                               otherButtonTitles:grantButtonTitle, nil];
        [self.preLocationPermissionAlertView show];
    } else {
        if (completionHandler) {
            completionHandler((status == kCLAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualLocationPermissionAlert
{
	[self postWillDisplayPermissions:clusterPermissionTypeLocation];

	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
	
#ifdef __IPHONE_8_0
	
	if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
		[self.locationManager requestAlwaysAuthorization];
	} else {
		[self.locationManager startUpdatingLocation];
	}
#else
	[self.locationManager startUpdatingLocation];
#endif
	
}


- (void) fireLocationPermissionCompletionHandler
{
	[self postDidDisplayPermissions:clusterPermissionTypeLocation];
	
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (self.locationPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == kCLAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == kCLAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == kCLAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == kCLAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.locationPermissionCompletionHandler((status == kCLAuthorizationStatusAuthorized),
                                                 userDialogResult,
                                                 systemDialogResult);
        self.locationPermissionCompletionHandler = nil;
    }
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation], self.locationManager = nil;
    }
}


#pragma mark CLLocationManagerDelegate

- (void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status != kCLAuthorizationStatusNotDetermined) {
        [self fireLocationPermissionCompletionHandler];
    }
}

#pragma mark - Calendar Permissions Help

- (void) showCalendarPermissionsWithTitle:(NSString *)requestTitle
                                  message:(NSString *)message
                          denyButtonTitle:(NSString *)denyButtonTitle
                         grantButtonTitle:(NSString *)grantButtonTitle
									store:(EKEventStore **)store
							   entityType:(EKEntityType)entityType
                        completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
	if (requestTitle.length == 0) {
        requestTitle = @"Access Calendar?";
    }
    if (denyButtonTitle.length == 0) {
        denyButtonTitle = @"Not Now";
    }
    if (grantButtonTitle.length == 0) {
        grantButtonTitle = @"Give Access";
    }
	*store = [[EKEventStore alloc] init];
	self.eventStore = *store;
	self.eventEntityType = entityType;
	EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:entityType];
    if (status == EKAuthorizationStatusNotDetermined) {
		[self postWillDisplayPrePermissions:clusterPermissionTypeCalendar];
        self.calendarPermissionCompletionHandler = completionHandler;
        self.preCalendarPermissionAlertView = [[UIAlertView alloc] initWithTitle:requestTitle
                                                                      message:message
                                                                     delegate:self
                                                            cancelButtonTitle:denyButtonTitle
                                                            otherButtonTitles:grantButtonTitle, nil];
        [self.preCalendarPermissionAlertView show];
    } else {
        if (completionHandler) {
            completionHandler((status == EKAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}

- (void) showActualCalendarPermissionAlert
{
	[self postWillDisplayPermissions:clusterPermissionTypeCalendar];
	
    [self.eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
            [self fireCalendarPermissionCompletionHandler];
        });
	}];
}

- (void) fireCalendarPermissionCompletionHandler
{
	[self postDidDisplayPermissions:clusterPermissionTypeCalendar];
	
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:self.eventEntityType];
    if (self.calendarPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == EKAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == EKAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == EKAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == EKAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.calendarPermissionCompletionHandler((status == EKAuthorizationStatusAuthorized),
                                                 userDialogResult,
                                                 systemDialogResult);
        self.calendarPermissionCompletionHandler = nil;
    }
}

#pragma mark - Notifications

- (void) postWillDisplayPrePermissions:(NSString *)type
{
	[self postNotification:clusterPrePermissionsWillDisplayPrePermissionRequest type:type];
}

- (void) postDidDisplayPrePermissions:(NSString *)type
{
	[self postNotification:clusterPrePermissionsDidDisplayPrePermissionRequest type:type];
}

- (void) postWillDisplayPermissions:(NSString *)type
{
	[self postNotification:clusterPrePermissionsWillDisplayPermissionRequest type:type];
}

- (void) postDidDisplayPermissions:(NSString *)type
{
	[self postNotification:clusterPrePermissionsDidDisplayPermissionRequest type:type];
}

- (void) postNotification:(NSString *)notification type:(NSString *)type
{
	[[NSNotificationCenter defaultCenter] postNotificationName:notification object:self userInfo:@{ clusterPermissionTypeKey : type }];
}


#pragma mark - UIAlertViewDelegate


- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView == self.prePhotoPermissionAlertView) {
		[self postDidDisplayPrePermissions:clusterPermissionTypePhoto];
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, jerk.
            [self firePhotoPermissionCompletionHandler];
        } else {
            // User granted access, now show the REAL permissions dialog
            [self showActualPhotoPermissionAlert];
        }

        self.prePhotoPermissionAlertView = nil;
    } else if (alertView == self.preContactPermissionAlertView) {
		[self postDidDisplayPrePermissions:clusterPermissionTypeContacts];
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, that jerk.
            [self fireContactPermissionCompletionHandler];
        } else {
            // User granted access, now try to trigger the real contacts access
            [self showActualContactPermissionAlert];
        }
    } else if (alertView == self.preLocationPermissionAlertView) {
		[self postDidDisplayPrePermissions:clusterPermissionTypeLocation];
        if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, that jerk.
            [self fireLocationPermissionCompletionHandler];
        } else {
            // User granted access, now try to trigger the real location access
            [self showActualLocationPermissionAlert];
        }
    } else if (alertView == self.preCalendarPermissionAlertView) {
		[self postDidDisplayPrePermissions:clusterPermissionTypeCalendar];
		if (buttonIndex == alertView.cancelButtonIndex) {
            // User said NO, that jerk.
            [self fireCalendarPermissionCompletionHandler];
        } else {
            // User granted access, now try to trigger the real location access
            [self showActualCalendarPermissionAlert];
        }
	}
}

@end
