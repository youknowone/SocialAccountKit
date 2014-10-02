//
//  SocialErrorSample.m
//  SocialAccount
//
//  Created by Jeong YunWon on 2014. 9. 23..
//  Copyright (c) 2014 youknowone.org. All rights reserved.
//

#import "SocialAccount.h"
#import "SocialErrorSample.h"

BOOL SocialErrorHandleSample(NSError *error) {
    SocialErrorType type = SocialErrorTypeForError(error);
    NSString *title = nil;
    NSString *message = nil;
    switch (type) {
        case SocialErrorUnknown:
            title = @"SocialAccountKit error";
            message = error.description;
            break;
        case SocialErrorNoAccountsAvailable:
            title = @"No available accounts";
            message = @"Add accounts in Settings->Facebook/Twitter";
            break;
        case SocialErrorAccountNotAvailable:
            title = @"This account is not available";
            message = @"It maybe an error of usage of Accounts API.";
            break;
        case SocialErrorDisallowedByUser:
            title = @"User disgranted";
            message = @"Settings->Facebook/Twitter and fix the setting.";
            break;
        case SocialErrorMatchingAccountNotFound:
            title = @"Social account is changed.";
            message = @"App cannot find social account which is used for last authorization.";
            break;
        case SocialErrorFacebookServerNotAvailble:
        case SocialErrorFacebookResponseNotInterpretable:
            title = @"Facebook is not available";
            message = @"It may be a problem of facebook service or network. Try it later.";
            break;
        case SocialErrorTwitterReverseAuthFailed:
            title = @"Twitter reverse auth is not available";
            message = @"It may be a problem of facebook service or network. Try it later.";
            break;
        default:
            assert(false);
            break;
    }
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    });
    return type == SocialErrorUnknown;
}
