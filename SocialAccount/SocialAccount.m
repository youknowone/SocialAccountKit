//
//  SocialAccount.m
//  SocialAccount
//
//  Created by Jeong YunWon on 2014. 9. 23..
//  Copyright (c) 2014 youknowone.org. All rights reserved.
//

#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import <FoundationExtension/FoundationExtension.h>

#import "SocialAccount.h"

#import <cdebug/debug.h>

@interface SASocialManager () {
    ACAccount *_facebookAccount;
    ACAccount *_twitterAccount;
}

@end


@interface SASocialAccount () {
    ACAccount *_accountCandidate;
}

@end


@implementation SASocialAccount

- (instancetype)initWithManager:(SASocialManager *)manager {
    self = [super init];
    if (self != nil) {
        self->_manager = manager;
        self->_dataSource = manager;
        self->_type = nil; // must be set in subclasses
    }
    return self;
}

- (ACAccount *)accountForAuthorizedIdentifier:(NSError *__autoreleasing *)errorPtr {
    ACAccount *account = nil;
    NSString *identifier = [self.dataSource authorizedAccountIdentifierForSocialAccount:self];
    for (ACAccount *anAccount in [self.manager.store accountsWithAccountType:self.type]) {
        if ([anAccount.identifier isEqualToString:identifier]) {
            account = anAccount;
            break;
        }
    }
    if (account == nil && errorPtr != NULL) {
        *errorPtr = [NSError errorWithDomain:SocialErrorDomain(@"account") code:1 userInfo:@{@"expected": identifier ?: [NSNull null]}];
    }
    return account;
}

- (ACAccount *)accountCandidateForLogin {
    return self->_accountCandidate;
}

- (void)saveAccount:(ACAccount *)account completion:(ACAccountStoreSaveCompletionHandler)completion {
    [self.manager.store saveAccount:account withCompletionHandler:completion];
}

- (void)removeSavedAccount {
    ACAccount *account = [self accountForAuthorizedIdentifier:NULL];
    if (account) {
        [self.manager.store removeAccount:account withCompletionHandler:NULL];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != actionSheet.cancelButtonIndex) {
        NSArray *accounts = [actionSheet associatedObjectForKey:@"accounts"];
        ACAccount *account = accounts[buttonIndex - 1];
        self->_accountCandidate = account;
        [self remoteSessionLoginAccountDidSelectedWithCompletion:[actionSheet associatedObjectForKey:@"completion"]];
    }
}

- (void)requestAccessToAccountsWithCompletion:(ACAccountStoreRequestAccessCompletionHandler)completion {
    [self.manager.store requestAccessToAccountsWithType:self.type options:nil completion:completion];
}

- (void)requestOnlyIfAccountIsNotAccessibleByIdentifierWithCompletion:(ACAccountStoreRequestAccessCompletionHandler)completion {
    if ([self accountForAuthorizedIdentifier:NULL]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^(void) {
            completion(YES, nil);
        });
    } else {
        [self requestAccessToAccountsWithCompletion:^(BOOL granted, NSError *error) {
            if (granted) {
                NSError *error = nil;
                ACAccount *account = [self accountForAuthorizedIdentifier:&error];
                if (account) {
                    completion(YES, nil);
                } else {
                    completion(NO, error);
                }
            } else {
                completion(NO, error ?: [NSError errorWithDomain:@"com.apple.accounts.disgrant" code:0 userInfo:@{@"description": @"User disgranted facebook account"}]);
            }
        }];
    }
}

- (void)requestRemoteSessionLoginWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion {
    [self requestAccessToAccountsWithCompletion:^(BOOL granted, NSError *error) {
        if (granted) {
            NSArray *accounts = [self.manager.store accountsWithAccountType:self.type];
            if (accounts.count > 1) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Accounts" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:nil];
                    [actionSheet setAssociatedObject:accounts forKey:@"accounts"];
                    [actionSheet setAssociatedObject:completion forKey:@"completion" policy:OBJC_ASSOCIATION_COPY_NONATOMIC];
                    for (ACAccount *account in accounts) {
                        [actionSheet addButtonWithTitle:[@"@%@" format:account.username]];
                    }
                    [actionSheet showInView:[UIApplication sharedApplication].windows.lastObject];
                });
            } else if (accounts.count == 1) {
                ACAccount *account = accounts.lastObject;
                self->_accountCandidate = account;
                [self remoteSessionLoginAccountDidSelectedWithCompletion:completion];
            } else {
                completion(nil, error ?: [NSError errorWithDomain:@"com.apple.accounts" code:6 userInfo:@{@"description": @"No available accounts"}]); // only twitter comes here
            }
        } else {
            completion(nil, error ?: [NSError errorWithDomain:@"com.apple.accounts.disgrant" code:0 userInfo:@{@"description": @"User disgranted facebook account"}]);
        }
    }];
}

- (void)remoteSessionLoginAccountDidSelectedWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion {
    completion(@(YES), nil);
}

- (void)getFriendsWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion {
    assert(false);
}

- (void)handleRequestResult:(NSData *)responseData error:(NSError *)error completion:(SASocialAPIRequestAccessCompletionHandler)completion {
    if (error == nil) {
        NSError *error = nil;
        id JSONObject = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
        if (error == nil) {
            completion(JSONObject, nil);
        } else {
            completion(nil, error);
        }
    } else {
        completion(nil, error);
    }
}

@end


@interface SAFacebookAccount ()

- (NSURL *)URLForEdge:(NSString *)edge;

@end


@implementation SAFacebookAccount

- (NSURL *)URLForEdge:(NSString *)edge {
    const NSString *format = @"https://graph.facebook.com/%@";
    return [format format:edge].URL;
}

- (instancetype)initWithManager:(SASocialManager *)manager {
    self = [super initWithManager:manager];
    if (self != nil) {
        self.type = [self.manager.store accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
    }
    return self;
}

- (void)requestAccessToAccountsWithCompletion:(ACAccountStoreRequestAccessCompletionHandler)completion {
    NSString *appID = [self.dataSource facebookAppIDForSocialAccount:self];
    NSDictionary *options = @{
                              ACFacebookAppIdKey: appID,
                              ACFacebookPermissionsKey: [self.dataSource facebookPermissionsKeyForSocialAccount:self],
                              ACFacebookAudienceKey: [self.dataSource facebookAudienceForSocialAccount:self] ?: ACFacebookAudienceFriends,
                              };
    [self.manager.store requestAccessToAccountsWithType:self.type options:options completion:completion];
}

- (void)remoteSessionLoginAccountDidSelectedWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion {
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodGET URL:[self URLForEdge:@"me"] parameters:nil];
    request.account = self.accountCandidateForLogin;
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *URLResponse, NSError *error) {
        if (error == nil) {
            NSError *error = nil;
            id JSONObject = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
            if (error == nil) {
                completion(JSONObject, nil);
            } else {
                completion(nil, [NSError errorWithDomain:SocialErrorDomain(@"facebook") code:2 userInfo:@{}]);
            }
        } else {
            // more error handling required?
            dlog(1, @"network error: %@", error);
            completion(nil, [NSError errorWithDomain:SocialErrorDomain(@"facebook") code:1 userInfo:@{}]);
        }
    }];
}

- (void)publishFeed:(NSDictionary *)feed completion:(SASocialAPIRequestAccessCompletionHandler)completion {
    NSError *error = nil;
    ACAccount *account = [self accountForAuthorizedIdentifier:&error];
    if (account == nil) {
        completion(nil, error);
        return;
    }

    NSURL *feedURL = [self URLForEdge:@"/me/feed"];
    SLRequest *feedRequest = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodPOST URL:feedURL parameters:feed];
    feedRequest.account = account;

    [feedRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        [self handleRequestResult:responseData error:error completion:completion];
    }];
}

- (void)publishFeedWithMessage:(NSString *)message completion:(SASocialAPIRequestAccessCompletionHandler)completion {
    [self publishFeed:@{@"message": message} completion:completion];
}

- (void)getFriendsWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion {
    NSError *error = nil;
    ACAccount *account = [self accountForAuthorizedIdentifier:&error];
    if (account == nil) {
        completion(nil, error);
        return;
    }

    NSURL *URL = [self URLForEdge:@"/me/friends"];
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodGET URL:URL parameters:@{}];
    request.account = account;
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *URLResponse, NSError *error) {
        [self handleRequestResult:responseData error:error completion:completion];
    }];
}

@end


@implementation SATwitterAccount

- (instancetype)initWithManager:(SASocialManager *)manager {
    self = [super initWithManager:manager];
    if (self != nil) {
        self.type = [self.manager.store accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
        self->_reverseAuth = [[TRATwitterReverseAuth alloc] initWithDelegate:self];
    }
    return self;
}

- (void)remoteSessionLoginAccountDidSelectedWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion {
    [self.reverseAuth requestCredentialsForAccount:self.accountCandidateForLogin completion:^(NSDictionary *credentials, NSError *error) {
        if (credentials.count > 0) {
            completion(credentials, nil);
        } else {
            dlog(1, @"error: %@", error);
            completion(nil, [NSError errorWithDomain:@"twitter" code:0 userInfo:@{}]);
        }
    }];
}

- (void)updateStatus:(NSString *)status completion:(SASocialAPIRequestAccessCompletionHandler)completion {
    NSDictionary *message = @{@"status": status};
    NSURL *requestURL = @"https://api.twitter.com/1/statuses/update.json".URL;

    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:requestURL parameters:message];
    NSError *error = nil;
    request.account = [self accountForAuthorizedIdentifier:&error];
    if (request.account == nil) {
        completion(nil, error);
        return;
    }
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        [self handleRequestResult:responseData error:error completion:completion];
    }];
}

- (void)getFriendsWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion {
    // following
    NSURL *requestURL = @"https://api.twitter.com/1.1/friends/list.json".URL;
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:requestURL parameters:@{}];
    NSError *error = nil;
    request.account = [self accountForAuthorizedIdentifier:&error];
    if (request.account == nil) {
        completion(nil, error);
        return;
    }
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        [self handleRequestResult:responseData error:error completion:completion];
    }];
}

#pragma mark -

- (NSString *)APIKeyForTwitterReverseAuth:(TRATwitterReverseAuth *)reverseAuth {
    return [self.dataSource APIKeyForTwitterReverseAuth:reverseAuth];
}

- (NSString *)APISecretForTwitterReverseAuth:(TRATwitterReverseAuth *)reverseAuth {
    return [self.dataSource APISecretForTwitterReverseAuth:reverseAuth];
}

- (ACAccountStore *)accountStoreForTwitterReverseAuth:(TRATwitterReverseAuth *)reverseAuth {
    if ([self.dataSource respondsToSelector:_cmd]) {
        return [self.dataSource accountStoreForTwitterReverseAuth:reverseAuth];
    } else {
        return self.manager.store;
    }
}


@end



@implementation SASocialManager

SASocialManager *_SASocialManagerDefaultObject = nil;

+ (void)initialize {
    if (self == [SASocialManager class]) {
        _SASocialManagerDefaultObject = [[self alloc] init];
    }
}

+ (SASocialManager *)defaultManager {
    dassert(_SASocialManagerDefaultObject);
    return _SASocialManagerDefaultObject;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        self->_store = [[ACAccountStore alloc] init];
        self->_facebook = [[SAFacebookAccount alloc] initWithManager:self];
        self->_twitter = [[SATwitterAccount alloc] initWithManager:self];
    }
    return self;
}

- (void)removeAllSavedAccounts {
    [self.facebook removeSavedAccount];
    [self.twitter removeSavedAccount];
}

#pragma mark - protocol aggregation


- (NSString *)authorizedAccountIdentifierForSocialAccount:(SASocialAccount *)account {
    return [self.dataSource authorizedAccountIdentifierForSocialAccount:account];
}

- (NSString *)facebookAppIDForSocialAccount:(SASocialAccount *)account {
    return [self.dataSource facebookAppIDForSocialAccount:account];
}

- (NSArray *)facebookPermissionsKeyForSocialAccount:(SASocialAccount *)account {
    return [self.dataSource facebookPermissionsKeyForSocialAccount:account];
}

- (NSString *)facebookAudienceForSocialAccount:(SASocialAccount *)account {
    if ([self.dataSource respondsToSelector:_cmd]) {
        return [self.dataSource facebookAudienceForSocialAccount:account];
    }
    return nil;
}

- (NSString *)APIKeyForTwitterReverseAuth:(TRATwitterReverseAuth *)reverseAuth {
    if ([self.dataSource respondsToSelector:_cmd]) {
        return [self.dataSource APIKeyForTwitterReverseAuth:reverseAuth];
    }
    return nil;
}

- (NSString *)APISecretForTwitterReverseAuth:(TRATwitterReverseAuth *)reverseAuth {
    if ([self.dataSource respondsToSelector:_cmd]) {
        return [self.dataSource APISecretForTwitterReverseAuth:reverseAuth];
    }
    return nil;
}

- (ACAccountStore *)accountStoreForTwitterReverseAuth:(TRATwitterReverseAuth *)reverseAuth {
    if ([self.dataSource respondsToSelector:_cmd]) {
        return [self.dataSource accountStoreForTwitterReverseAuth:reverseAuth];
    } else {
        return self.store;
    }
}

@end


NSString *SocialErrorDomain(NSString *suffix) {
    NSString *domain = @"social";
    if (suffix) {
        return [domain stringByAppendingFormat:@".%@", suffix];
    }
    return domain;
}


SocialErrorType SocialErrorTypeForError(NSError *error) {
    if ([error.domain isEqualToString:@"com.apple.accounts"] && error.code == 6) {
        return SocialErrorNoAccountsAvailable;
    }
    if ([error.domain isEqualToString:@"com.apple.accounts.disgrant"]) {
        return SocialErrorDisallowedByUser;
    }
    if ([error.domain isEqualToString:SocialErrorDomain(@"account")]) {
        return SocialErrorMatchingAccountNotFound;
    }
    if ([error.domain isEqualToString:SocialErrorDomain(@"facebook")]) {
        switch (error.code) {
            case 1:
                return SocialErrorFacebookServerNotAvailble;
            case 2:
                return SocialErrorFacebookResponseNotInterpretable;
        }
    }
    if ([error.domain isEqualToString:SocialErrorDomain(@"twitter")]) {
        switch (error.code) {
            case 0:
                return SocialErrorTwitterReverseAuthFailed;
        }
    }
    return SocialErrorUnknown;
}
