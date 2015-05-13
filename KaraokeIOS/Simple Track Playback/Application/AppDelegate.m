
#import "AppDelegate.h"
#import <Spotify/Spotify.h>
#import "Config.h"
#import "ViewController.h"

#define kSessionUserDefaultsKey "SpotifySession"


@implementation AppDelegate

-(void)enableAudioPlaybackWithSession:(SPTSession *)session {
    NSData *sessionData = [NSKeyedArchiver archivedDataWithRootObject:session];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:sessionData forKey:@kSessionUserDefaultsKey];
    [userDefaults synchronize];
    ViewController *viewController = (ViewController *)self.window.rootViewController;
    [viewController handleNewSession:session];
}

- (void)openLoginPage {
    SPTAuth *auth = [SPTAuth defaultInstance];

    NSString *swapUrl = @kTokenSwapServiceURL;
    NSURL *loginURL;
    
    if (swapUrl == nil || [swapUrl isEqualToString:@""]) {
        loginURL = [auth loginURLForClientId:@kClientId
                         declaredRedirectURL:[NSURL URLWithString:@kCallbackURL]
                                      scopes:@[SPTAuthStreamingScope]
                            withResponseType:@"token"];
    }
    else {
        loginURL = [auth loginURLForClientId:@kClientId
                         declaredRedirectURL:[NSURL URLWithString:@kCallbackURL]
                                      scopes:@[SPTAuthStreamingScope]];

    }
    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [[UIApplication sharedApplication] openURL:loginURL];
    });
}

- (void)renewTokenAndEnablePlayback {
    id sessionData = [[NSUserDefaults standardUserDefaults] objectForKey:@kSessionUserDefaultsKey];
    SPTSession *session = sessionData ? [NSKeyedUnarchiver unarchiveObjectWithData:sessionData] : nil;
    SPTAuth *auth = [SPTAuth defaultInstance];

    [auth renewSession:session withServiceEndpointAtURL:[NSURL URLWithString:@kTokenRefreshServiceURL] callback:^(NSError *error, SPTSession *session) {
        if (error) {
            NSLog(@"*** Error renewing session: %@", error);
            return;
        }
        
        [self enableAudioPlaybackWithSession:session];
    }];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    id sessionData = [[NSUserDefaults standardUserDefaults] objectForKey:@kSessionUserDefaultsKey];
    SPTSession *session = sessionData ? [NSKeyedUnarchiver unarchiveObjectWithData:sessionData] : nil;

    NSString *refreshUrl = @kTokenRefreshServiceURL;

    if (session) {
        if ([session isValid]) {
            [self enableAudioPlaybackWithSession:session];
        } else {
            if (refreshUrl == nil || [refreshUrl isEqualToString:@""]) {
                [self openLoginPage];
            } else {
                [self renewTokenAndEnablePlayback];
            }
        }
    } else {
        [self openLoginPage];
    }

    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {

    SPTAuthCallback authCallback = ^(NSError *error, SPTSession *session) {

        if (error != nil) {
            NSLog(@"*** Auth error: %@", error);
            return;
        }

        NSData *sessionData = [NSKeyedArchiver archivedDataWithRootObject:session];
        [[NSUserDefaults standardUserDefaults] setObject:sessionData
                                                  forKey:@kSessionUserDefaultsKey];
        [self enableAudioPlaybackWithSession:session];
    };
    
    
    NSString *swapUrl = @kTokenSwapServiceURL;
    if ([[SPTAuth defaultInstance] canHandleURL:url withDeclaredRedirectURL:[NSURL URLWithString:@kCallbackURL]]) {
        if (swapUrl == nil || [swapUrl isEqualToString:@""]) {
            [[SPTAuth defaultInstance] handleAuthCallbackWithTriggeredAuthURL:url callback:authCallback];
        } else { 
            [[SPTAuth defaultInstance] handleAuthCallbackWithTriggeredAuthURL:url
                                                tokenSwapServiceEndpointAtURL:[NSURL URLWithString:swapUrl]
                                                                     callback:authCallback];
        }
        return YES;
    }
    
    return NO;
}

@end
