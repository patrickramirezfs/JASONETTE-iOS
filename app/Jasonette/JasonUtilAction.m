//
//  JasonUtilAction.m
//  Jasonette
//
//  Copyright © 2016 gliechtenstein. All rights reserved.
//
#import "JasonUtilAction.h"
#import "SDWebImageDownloader.h"

@implementation JasonUtilAction
- (void)banner{
    NSString *title = [self.options[@"title"] description];
    NSString *description = [self.options[@"description"] description];
    NSString *type = self.options[@"type"];
    if(!title) title = @"Notice";
    if(!description) description = @"";
    if(!type) type = @"info";
    
    TWMessageBarMessageType type_code;
    if([type isEqualToString:@"error"]){
        type_code = TWMessageBarMessageTypeError;
    } else if([type isEqualToString:@"info"]){
        type_code = TWMessageBarMessageTypeInfo;
    } else {
        type_code = TWMessageBarMessageTypeSuccess;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [[TWMessageBarManager sharedInstance] showMessageWithTitle: title
                                                       description: description
                                                              type: type_code];
    });
    [[Jason client] success];
}




- (void)toast{
    NSString *type = self.options[@"type"];
    NSString *text = [self.options[@"text"] description];
    
    if(!type) type = @"success";
    if(!text) text = @"Updated";
    
    NSString *type_code;
    if([type isEqualToString:@"dark"]){
        type_code = JDStatusBarStyleDark;
    } else if([type isEqualToString:@"default"]){
        type_code = JDStatusBarStyleDefault;
    } else if([type isEqualToString:@"error"]){
        type_code = JDStatusBarStyleError;
    } else if([type isEqualToString:@"matrix"]){
        type_code = JDStatusBarStyleMatrix;
    } else if([type isEqualToString:@"success"]){
        type_code = JDStatusBarStyleSuccess;
    } else if([type isEqualToString:@"warning"]){
        type_code = JDStatusBarStyleWarning;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [JDStatusBarNotification showWithStatus:text dismissAfter:3.0 styleName:type_code];
    });
    [[Jason client] success];
}

- (void)alert{
    [[Jason client] loading:NO];
    NSString *title = [self.options[@"title"] description];
    NSString *description = [self.options[@"description"] description];
    NSString *ok_title = @"OK";
    
    if(self.options[@"ok_title"]) {
        ok_title = [self.options[@"ok_title"] description];
    }
    
    // 1. Instantiate alert
    UIAlertController *alert= [UIAlertController alertControllerWithTitle:title message:description preferredStyle:UIAlertControllerStyleAlert];
    
    // 2. Add Input field
    NSArray *form = self.options[@"form"];
    NSMutableDictionary *form_inputs = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *textFields = [[NSMutableDictionary alloc] init];
    if(form && form.count > 0){
        for(int i = 0 ; i < form.count ; i++){
            NSDictionary *input = form[i];
            if([input[@"type"] isEqualToString:@"hidden"]){
                if(input[@"value"]){
                    form_inputs[input[@"name"]] = input[@"value"];
                }
            } else if([input[@"type"] isEqualToString:@"secure"]){
                [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.secureTextEntry = YES;
                    textFields[input[@"name"]] = textField;
                    if(input[@"placeholder"]){
                        textField.placeholder = input[@"placeholder"];
                    }
                    if(input[@"value"]){
                        [textField setText:input[@"value"]];
                    }
                }];
            } else {
                // default is text field
                [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.secureTextEntry = NO;
                    textFields[input[@"name"]] = textField;
                    if(input[@"placeholder"]){
                        textField.placeholder = input[@"placeholder"];
                    }
                    if(input[@"value"]){
                        [textField setText:input[@"value"]];
                    }
                }];
            }
            
        }
    }
    
    
    // 3. Add buttons
    UIAlertAction *ok = [UIAlertAction actionWithTitle:ok_title style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            // Handle callback actions
        if(form && form.count > 0){
            for(NSString *input_name in textFields){
                UITextField *textField = (UITextField *)textFields[input_name];
                [form_inputs setObject:textField.text forKey:input_name];
            }
            [[Jason client] success: form_inputs];
        } else {
            [[Jason client] success];
        }
    }];
    [alert addAction:ok];
    
    if (!self.options[@"hide_cancel"]) {
        UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [[Jason client] error];
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];
        
        [alert addAction:cancel];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        alert.modalPresentationStyle = UIModalPresentationFullScreen;
        [self.VC.navigationController presentViewController:alert animated:YES completion:nil];
    });
}

- (void)redirectToStore{
    NSURL *appStoreLink = [self appStoreURL];
    [[UIApplication sharedApplication] openURL:appStoreLink  options:@{} completionHandler:nil];
}

- (void)redirectToSettings{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];

}

- (void)share{
    NSArray *items = self.options[@"items"];
    NSMutableArray *share_items = [[NSMutableArray alloc] init];
    __block NSInteger counter = items.count;
    if(items && items.count > 0){
        for(int i = 0 ; i < items.count ; i++){
            NSDictionary *item = items[i];
            if(item[@"type"]){
                if([item[@"type"] isEqualToString:@"image"]){
                    NSString *url = item[@"url"];
                    NSString *file_url = item[@"file_url"];
                    if(url){
                        SDWebImageManager *manager = [SDWebImageManager sharedManager];
                        [manager loadImageWithURL:[NSURL URLWithString:url]
                                          options:0
                                         progress:nil
                                        completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
                            if (image) {
                                [share_items addObject:image];
                            }
                            counter--;
                            if(counter == 0) [self openShareWith:share_items];
                        }];
                    } else if(file_url){
                        [share_items addObject:file_url];
                        counter--;
                        if(counter == 0) [self openShareWith:share_items];
                    } else if(item[@"data"]){
                        NSData *data = [[NSData alloc] initWithBase64EncodedString:item[@"data"] options:0];
                        UIImage *image = [UIImage imageWithData:data];
                        [share_items addObject:image];
                        counter--;
                        if(counter == 0) [self openShareWith:share_items];
                    }
                } else if([item[@"type"] isEqualToString:@"audio"]){
                    NSString *url = item[@"file_url"];
                    if(url){
                        NSURL *file_url = [NSURL fileURLWithPath:url isDirectory:NO];
                        [share_items addObject:file_url];
                        counter--;
                        if(counter == 0) [self openShareWith:share_items];
                    }
                } else if([item[@"type"] isEqualToString:@"video"]){
                    NSString *url = item[@"file_url"];
                    if(url){
                        NSURL *file_url = [NSURL fileURLWithPath:url isDirectory:NO];
                        [share_items addObject:file_url];
                        counter--;
                        if(counter == 0) [self openShareWith:share_items];
                    }
                } else if([item[@"type"] isEqualToString:@"text"]){
                    if(item[@"text"]){
                        [share_items addObject:[item[@"text"] description]];
                    }
                    counter--;
                } else if([item[@"type"] isEqualToString:@"url"]){
                    if(item[@"url"]){
                        [share_items addObject:[NSURL URLWithString: [item[@"url"] description]]];
                    }
                    counter--;
                }
            }
        }
        
        if(counter == 0){
            // this means it can immediately call UIActivityController (No image)
            // Otherwise this should be completed inside the image download complete event
            [self openShareWith:share_items];
        }
    } else {
        [[Jason client] success];
    }
}
- (void)clipboard{
    NSArray *items = self.options[@"items"];
    if(items && items.count > 0){
        UIPasteboard *pasteBoard=[UIPasteboard generalPasteboard];
        NSMutableArray *to_copy = [[NSMutableArray alloc] init];
        for(int i = 0 ; i < items.count ; i++){
            NSDictionary *item = items[i];
            
            if([item[@"type"] isEqualToString:@"gif"]){
                if(item[@"url"]){
                    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:item[@"url"]]];
                    NSDictionary *res = [NSDictionary dictionaryWithObject:data forKey:(NSString *)kUTTypeGIF];
                    [to_copy addObject:res];
                }
            } else if([item[@"type"] isEqualToString:@"text"]){
                if(item[@"text"]){
                    NSDictionary *res = [NSDictionary dictionaryWithObject:[item[@"text"] description] forKey:(NSString *)kUTTypeUTF8PlainText];
                    [to_copy addObject:res];
                }
            } else if([item[@"type"] isEqualToString:@"image"]){
                if(item[@"url"]){
                    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:item[@"url"]]];
                    NSDictionary *res = [NSDictionary dictionaryWithObject:data forKey:(NSString *)kUTTypePNG];
                    [to_copy addObject:res];
                }
            }
        }
        [pasteBoard setItems:to_copy];
    }
    [[Jason client] success];

}
- (void)openShareWith:(NSArray *)items{
    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    
    // Exclude all activities except AirDrop.
    NSArray *excludeActivities = @[UIActivityTypePostToFlickr, UIActivityTypePostToVimeo];
    controller.excludedActivityTypes = excludeActivities;
    if(controller.popoverPresentationController){
        controller.popoverPresentationController.sourceView = self.VC.view;
    }
    
    // Present the controller
    [controller setCompletionWithItemsHandler:
      ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
          [[Jason client] success];
    }];

    dispatch_async(dispatch_get_main_queue(), ^{
        controller.modalPresentationStyle = UIModalPresentationFullScreen;
        [self.VC.navigationController presentViewController:controller animated:YES completion:nil];
    });

}
- (void)picker{
    NSString *title = [self.options[@"title"] description];
    NSArray *items = self.options[@"items"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    for(int i = 0 ; i < items.count ; i++){
        NSDictionary *item = items[i];
        UIAlertAction *action = [UIAlertAction actionWithTitle:[item[@"text"] description]
                                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                                  if(item[@"href"]){
                                                                      [[Jason client] go:item[@"href"]];
                                                                  } else if(item[@"action"]){
                                                                      [[Jason client] call:item[@"action"]];
                                                                  }
                                                              }];
        [alert addAction:action];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.VC.view;
            alert.popoverPresentationController.sourceRect = CGRectMake(self.VC.view.bounds.size.width / 2.0, self.VC.view.bounds.size.height / 2.0, 1.0, 1.0);
            [alert.popoverPresentationController setPermittedArrowDirections:0];
        }
        alert.modalPresentationStyle = UIModalPresentationFullScreen;
        [self.VC.navigationController presentViewController:alert animated:YES completion:nil]; // 6
    });
    
}
    
- (void)datepicker{
    RMActionControllerStyle style = RMActionControllerStyleWhite;
    NSString *title = @"Select";
    NSString *description = @"";
    if(self.options){
        if(self.options[@"title"]){
            title = [self.options[@"title"] description];
        }
        if(self.options[@"description"]){
            description = [self.options[@"description"] description];
        }
    }

    RMAction *selectAction = [RMAction actionWithTitle:@"Ok" style:RMActionStyleDone andHandler:^(RMActionController *controller) {
        NSDate *date = ((UIDatePicker *)controller.contentView).date;
        NSString *res = [NSString stringWithFormat:@"%.0f", [date timeIntervalSince1970]];
        [[Jason client] success:@{@"value": res}];
    }];
    
    //Create cancel action
    RMAction *cancelAction = [RMAction actionWithTitle:@"Cancel" style:RMActionStyleCancel andHandler:^(RMActionController *controller) {
        [[Jason client] finish];
    }];
    
    //Create date selection view controller
    RMDateSelectionViewController *dateSelectionController = [RMDateSelectionViewController actionControllerWithStyle:style selectAction:selectAction andCancelAction:cancelAction];
    dateSelectionController.title = title;
    dateSelectionController.message = description;
    
    //Now just present the date selection controller using the standard iOS presentation method
    dateSelectionController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self.VC.tabBarController presentViewController:dateSelectionController animated:YES completion:nil];

}

- (NSURL *)appStoreURL
{
    static NSURL *appStoreURL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appStoreURL = [self appStoreURLFromBundleName:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
    });
    return appStoreURL;
}

- (NSURL *)appStoreURLFromBundleName:(NSString *)bundleName
{
    NSURL *appStoreURL = [NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://itunes.com/app/%@", [self sanitizeAppStoreResourceSpecifier:bundleName]]];
    return appStoreURL;
}

- (NSString *)sanitizeAppStoreResourceSpecifier:(NSString *)resourceSpecifier
{
    /*
     https://developer.apple.com/library/ios/qa/qa1633/_index.html
     To create an App Store Short Link, apply the following rules to your company or app name:
     
     Remove all whitespace
     Convert all characters to lower-case
     Remove all copyright (©), trademark (™) and registered mark (®) symbols
     Replace ampersands ("&") with "and"
     Remove most punctuation (See Listing 2 for the set)
     Replace accented and other "decorated" characters (ü, å, etc.) with their elemental character (u, a, etc.)
     Leave all other characters as-is.
     */
    resourceSpecifier = [resourceSpecifier stringByReplacingOccurrencesOfString:@"&" withString:@"and"];
    resourceSpecifier = [[NSString alloc] initWithData:[resourceSpecifier dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] encoding:NSASCIIStringEncoding];
    resourceSpecifier = [resourceSpecifier stringByReplacingOccurrencesOfString:@"[!¡\"#$%'()*+,-./:;<=>¿?@\\[\\]\\^_`{|}~\\s\\t\\n]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, resourceSpecifier.length)];
    resourceSpecifier = [resourceSpecifier lowercaseString];
    return resourceSpecifier;
}

@end
