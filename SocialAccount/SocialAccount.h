//
//  SocialAccount.h
//  SocialAccount
//
//  Created by Jeong YunWon on 2014. 9. 23..
//  Copyright (c) 2014 youknowone.org. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <TwitterReverseAuth/TwitterReverseAuth.h>

typedef void(^SASocialAPIRequestAccessCompletionHandler)(id response, NSError *error);


@class SASocialManager;
@class SASocialAccount;

@protocol SASocialAccountDataSource <NSObject>

- (NSString *)authorizedAccountIdentifierForSocialAccount:(SASocialAccount *)account;

@end


@protocol SAFacebookAccountDataSource <SASocialAccountDataSource>

- (NSString *)facebookAppIDForSocialAccount:(SASocialAccount *)account;
- (NSArray *)facebookPermissionsKeyForSocialAccount:(SASocialAccount *)account;

@optional

- (NSString *)facebookAPIVersionForSocialAccount:(SASocialAccount *)account;
- (NSString *)facebookAudienceForSocialAccount:(SASocialAccount *)account;

@end


@protocol SATwitterAccountDataSource <SASocialAccountDataSource, TRATwitterReverseAuthDelegate>

@end


@protocol SASocialAccountAggregatedDataSource <SAFacebookAccountDataSource, SATwitterAccountDataSource>

@end


@interface SASocialAccount: NSObject<UIActionSheetDelegate>

@property(nonatomic,weak) SASocialManager *manager;
@property(nonatomic,weak) id<SASocialAccountDataSource> dataSource;

- (ACAccount *)accountForAuthorizedIdentifier:(NSError **)errorPtr;
- (ACAccount *)accountCandidateForLogin;
@property(nonatomic,strong) ACAccountType *type;

- (instancetype)initWithManager:(SASocialManager *)manager;

- (void)requestAccessToAccountsWithCompletion:(ACAccountStoreRequestAccessCompletionHandler)completion;
- (void)requestOnlyIfAccountIsNotAccessibleByIdentifierWithCompletion:(ACAccountStoreRequestAccessCompletionHandler)completion;
- (void)requestRemoteSessionLoginWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion;
- (void)saveAccount:(ACAccount *)account completion:(ACAccountStoreSaveCompletionHandler)completion;
- (void)removeSavedAccount;
- (void)getFriendsWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion;

@end


@interface SAFacebookAccount: SASocialAccount

@property(nonatomic,weak) id<SAFacebookAccountDataSource> dataSource;

- (void)getTaggableFriendsWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion;
- (void)getInvitableFriendsWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion;

- (void)publishFeed:(NSDictionary *)feed completion:(SASocialAPIRequestAccessCompletionHandler)completion;
- (void)publishFeedWithMessage:(NSString *)message completion:(SASocialAPIRequestAccessCompletionHandler)completion;

@end


@interface SATwitterAccount: SASocialAccount<TRATwitterReverseAuthDelegate>

@property(nonatomic,weak) id<SATwitterAccountDataSource> dataSource;

@property(nonatomic,readonly) TRATwitterReverseAuth *reverseAuth;

- (void)updateStatus:(NSString *)status completion:(SASocialAPIRequestAccessCompletionHandler)completion;
- (void)getFollowingsWithCompletion:(SASocialAPIRequestAccessCompletionHandler)completion;

@end


@interface SASocialManager: NSObject<SASocialAccountAggregatedDataSource>

+ (SASocialManager *)defaultManager;

@property(nonatomic,weak) id<SASocialAccountAggregatedDataSource> dataSource;

@property(nonatomic,readonly) ACAccountStore *store;
@property(nonatomic,readonly) SAFacebookAccount *facebook;
@property(nonatomic,readonly) SATwitterAccount *twitter;

- (void)removeAllSavedAccounts;

@end


typedef enum : NSUInteger {
    SocialErrorUnknown,
    SocialErrorNoAccountsAvailable,
    SocialErrorAccountNotAvailable,
    SocialErrorDisallowedByUser,
    SocialErrorMatchingAccountNotFound,

    SocialErrorFacebookServerNotAvailble,
    SocialErrorFacebookResponseNotInterpretable,

    SocialErrorTwitterReverseAuthFailed,
} SocialErrorType;

FOUNDATION_EXTERN NSString *SocialErrorDomain(NSString *suffix);
FOUNDATION_EXTERN SocialErrorType SocialErrorTypeForError(NSError *error);
