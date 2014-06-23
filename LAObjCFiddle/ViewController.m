//
//  ViewController.m
//  LAObjCFiddle
//
//  Created by Tom Elliott on 11/06/2014.
//  Copyright (c) 2014 Facebook. All rights reserved.
//

#import "ViewController.h"

#import <LocalAuthentication/LocalAuthentication.h>

static NSString *const kServiceName = @"MyVeryShinyNewService";
static NSString *const kAccountName = @"You";

@interface ViewController ()

@property (nonatomic, strong, readonly) UILabel *instructionLabel;
@property (nonatomic, strong, readonly) UIButton *goButton;
@property (nonatomic, strong, readonly) UIButton *saveButton;
@property (nonatomic, strong, readonly) NSString *secret;

@property (nonatomic, assign) BOOL shouldRead;


@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  _instructionLabel = [[UILabel alloc] init];
  _instructionLabel.text = @"Login Below";
  _instructionLabel.textAlignment = NSTextAlignmentCenter;
  
  _goButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_goButton setTitle:@"Login" forState:UIControlStateNormal];
  [_goButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
  [_goButton.titleLabel setFont:[UIFont systemFontOfSize:15.0f]];
  [_goButton addTarget:self action:@selector(doBioAuth) forControlEvents:UIControlEventTouchUpInside];
  
  _saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_saveButton setTitle:@"Save Secret" forState:UIControlStateNormal];
  [_saveButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
  [_saveButton.titleLabel setFont:[UIFont systemFontOfSize:15.0f]];
  [_saveButton addTarget:self action:@selector(saveSecret) forControlEvents:UIControlEventTouchUpInside];
  [_saveButton setHidden:YES];
  
  _shouldRead = NO;
  
  NSDate *now = [NSDate date];
  NSString *nowStr = [NSDateFormatter localizedStringFromDate:now dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
  _secret = [NSString stringWithFormat:@"I am a secret stored at %@", nowStr];
  
  [self.view addSubview:_instructionLabel];
  [self.view addSubview:_goButton];
  [self.view addSubview:_saveButton];
  
  NSDictionary *viewsDict = NSDictionaryOfVariableBindings(_instructionLabel, _goButton, _saveButton);
  _instructionLabel.translatesAutoresizingMaskIntoConstraints = NO;
  _goButton.translatesAutoresizingMaskIntoConstraints = NO;
  _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[_instructionLabel]-[_goButton]-[_saveButton]" options:NSLayoutFormatAlignAllCenterX metrics:nil views:viewsDict]];
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_instructionLabel]-|" options:0 metrics:nil views:viewsDict]];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Handling Auth

- (void)doBioAuth
{
  LAContext *context = [[LAContext alloc] init];
  NSError *error = nil;

  if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
            localizedReason:NSLocalizedString(@"Fingerprint Plz!", nil)
                      reply:^(BOOL success, NSError *error) {
                        // Not main thread!
                        dispatch_async(dispatch_get_main_queue(), ^(){
                          if (success) {
                            [self handleAuthSuccess];
                          } else {
                            if (error.code == kLAErrorUserFallback) {
                              [self handleAuthUnknownForReason:@"Invoke our own passcode fallback"];
                            } else if (error.code == kLAErrorUserCancel) {
                              [self handleAuthUnknownForReason:@"User cancelled"];
                            } else {
                              [self handleAuthFailureWithError:error];
                            }
                          }
                        });
                      }];
  } else {
    NSLog(@"%@", error);
    [self handleAuthUnavailable];
  }
}

- (void)handleAuthSuccess
{
  NSLog(@"Auth success!");
  self.view.backgroundColor = [UIColor greenColor];
  [_saveButton setHidden:NO];
  
  _instructionLabel.text = @"W00p!";
}

- (void)handleAuthUnknownForReason:(NSString *)reason
{
  NSLog(@"%@", reason);
  self.view.backgroundColor = [UIColor orangeColor];
  
  _instructionLabel.text = @"Doh! Please Try again";
}

- (void)handleAuthFailureWithError:(NSError *)error
{
  NSLog(@"Auth error: %@", [error localizedDescription]);
  self.view.backgroundColor = [UIColor redColor];
  
  _instructionLabel.text = @"Doh! Please Try again";
}

- (void)handleAuthUnavailable
{
  _instructionLabel.text = @"Oh noes! TouchID not available";
  _goButton.enabled = NO;
}

#pragma mark - Keychain methods

- (void)saveSecret
{
  if (_shouldRead) {
    NSDictionary *query = @{
                                    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                    (__bridge id)kSecAttrService:kServiceName,
                                    (__bridge id)kSecAttrAccount:kAccountName,
                                    (__bridge id)kSecReturnData:@YES,
                                    (__bridge id<NSCopying>)kSecUseOperationPrompt:@"Please let me have it"
                                    };
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)(query), &result);
    
    if (status == errSecSuccess) {
      NSString *secret = [[NSString alloc] initWithData:(__bridge NSData *)result encoding:NSUTF8StringEncoding];
      _instructionLabel.text = secret;
      _shouldRead = NO;
    } else {
      NSString *result = [NSString stringWithFormat:@"Secret not Read :( We got an error code %d", (int)status];
      _instructionLabel.text = result;
      NSLog(@"%@", result);
    }
  } else {
    CFErrorRef error;
    
    // TODO: Why can't we use kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly?
    // This seemed to work when we had kSecAttrAccessibleAlways. But then it stopped
    SecAccessControlRef sacObject = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleAlways, kSecAccessControlUserPresence, &error);
    
    NSData *secret = [_secret dataUsingEncoding:NSUTF8StringEncoding];
 
    NSDictionary *query = @{
                            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService:kServiceName,
                            (__bridge id)kSecAttrAccount:kAccountName,
                            (__bridge id)kSecValueData:secret,
                            (__bridge id)kSecAttrAccessControl:(__bridge id)sacObject
                            };
    
    //OSStatus delStatus = SecItemDelete((__bridge CFDictionaryRef)(query));
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, nil);
    
    if (status == errSecSuccess) {
      _instructionLabel.text = @"Secret Saved";
      [_saveButton setTitle:@"Read Secret" forState:UIControlStateNormal];
      _shouldRead = YES;
    } else {
      NSString *result = [NSString stringWithFormat:@"Secret not Saved :( We got an error code %d", (int)status];
      _instructionLabel.text = result;
      NSLog(@"%@", result);
    }
  }
}

@end
