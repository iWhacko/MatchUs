//
//  LoginViewController.m
//  MatchUs
//
//  Created by Rhenz on 2/13/15.
//  Copyright (c) 2015 JLCS. All rights reserved.
//

#import "LoginViewController.h"

//Facebook
#import <FacebookSDK/FacebookSDK.h>
#import <ParseFacebookUtils/PFFacebookUtils.h>

@interface LoginViewController ()

@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) NSMutableData *imageData;

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.activityIndicator.hidden = YES;
    
}

-(void)viewDidAppear:(BOOL)animated
{
    if ([PFUser currentUser] && [PFFacebookUtils isLinkedWithUser:[PFUser currentUser]]) {
        [self updateUserInformation];
        [self performSegueWithIdentifier:@"loginToTabBarSegue" sender:self];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - IBActions/UIButtons
- (IBAction)loginButtonPressed:(id)sender
{
    self.activityIndicator.hidden = NO;
    [self.activityIndicator startAnimating];
    
    NSArray *permissionsArray = @[@"user_about_me", @"user_interests", @"user_relationships", @"user_birthday", @"user_location", @"user_relationship_details"];
    
    [PFFacebookUtils logInWithPermissions:permissionsArray block:^(PFUser *user, NSError *error) {
        
        [self.activityIndicator stopAnimating];
        self.activityIndicator.hidden = YES;
        
        if (!user) {
            if (!error) {
                [self alertViewWithTitle:@"Log In Error" andMessage:@"The Facebook Login was canceled"];
            }
            else {
                [self alertViewWithTitle:@"Log In Error" andMessage:[error description]];
            }
        }
        
        else {
            [self updateUserInformation];
            [self performSegueWithIdentifier:@"loginToTabBarSegue" sender:self];
        }
        
    }];
    
    
}

#pragma mark - Alert Controller
- (void)alertViewWithTitle:(NSString *)title andMessage:(NSString *)message
{
    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        // Do nothing
    }];
    
    [alertView addAction:cancel];
    
    [self presentViewController:alertView animated:YES completion:nil];
}

#pragma mark - Helper Methods
- (void)updateUserInformation
{
    FBRequest *fbRequest = [FBRequest requestForMe];
    
    [fbRequest startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        
        NSLog(@"%@", result);
        
        if (!error) {
            NSDictionary *userDictionary = (NSDictionary *)result;
            
            //create URL
            NSString *facebookID = userDictionary[@"id"];
            NSURL *pictureURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=large&return_ssl_resources=1",facebookID]];
            
            
            NSMutableDictionary *userProfile = [[NSMutableDictionary alloc] initWithCapacity:8];
            
            if (userDictionary[kUserProfileNameKey]) {
                userProfile[kUserProfileNameKey] = userDictionary[kUserProfileNameKey];
            }
            
            if (userDictionary[kUserProfileFirstNameKey]) {
                userProfile[kUserProfileFirstNameKey] = userDictionary[kUserProfileFirstNameKey];
            }
            
            if (userDictionary[kUserProfileLocationKey][kUserProfileNameKey]) {
                userProfile[kUserProfileLocationKey] = userDictionary[kUserProfileLocationKey][kUserProfileNameKey];
            }
            
            if (userDictionary[kUserProfileGenderKey]) {
                userProfile[kUserProfileGenderKey] = userDictionary[kUserProfileGenderKey];
            }
            
            if (userDictionary[kUserProfileBirthdayKey]) {
                userProfile[kUserProfileBirthdayKey] = userDictionary[kUserProfileBirthdayKey];
            }
            
            if (userDictionary[kUserProfileInterestedInKey]) {
                userProfile[kUserProfileInterestedInKey] = userDictionary[kUserProfileInterestedInKey];
            }
            
            if ([pictureURL absoluteString]) {
                userProfile[kUserProfilePictureURL] = [pictureURL absoluteString];
            }
            
            [[PFUser currentUser] setObject:userProfile forKey:kUserProfileKey];
            [[PFUser currentUser] saveInBackground];
            
            [self requestImage];
        }
    
        
        else {
            [self alertViewWithTitle:@"Error" andMessage:error.localizedDescription];
        }
    }];
}

- (void)uploadPFFileToParse:(UIImage *)image
{
    NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
    
    if (!imageData) {
        NSLog(@"imageData not found.");
        return;
    }
    
    PFFile *photoFile = [PFFile fileWithData:imageData];
    [photoFile saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (succeeded) {
            // Photo
            PFObject *photo = [PFObject objectWithClassName:kPhotoClassKey];
            [photo setObject:[PFUser currentUser] forKey:kPhotoUserKey];
            [photo setObject:photoFile forKey:kPhotoPictureKey];
            
            [photo saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                if (succeeded) {
                    NSLog(@"photo saved successfully");
                }
                
            }];
        }
    }];
}

- (void)requestImage
{
    PFQuery *query = [PFQuery queryWithClassName:kPhotoClassKey];
    [query whereKey:kPhotoUserKey equalTo:[PFUser currentUser]];
    
    [query countObjectsInBackgroundWithBlock:^(int number, NSError *error) {
        if (number == 0) {
            // No photos
            
            PFUser *user = [PFUser currentUser];
            self.imageData = [[NSMutableData alloc] init];
            
            NSURL *profilePictureURL = [NSURL URLWithString:user[kUserProfileKey][kUserProfilePictureURL]];
            
            NSURLRequest *urlRequest = [NSURLRequest requestWithURL:profilePictureURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:4.0];
            
            NSURLConnection *urlConnection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self];
            
            if (!urlConnection) {
                NSLog(@"failed to download picture");
            }
        }
    }];
}

#pragma mark - NSURLConnectionDataDelegate
-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.imageData appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    UIImage *profileImage = [UIImage imageWithData:self.imageData];
    
    [self uploadPFFileToParse:profileImage];
}

@end
