//
//  ExportManager.m
//  ParseToCSV
//
//  Created by William Welbes on 6/11/14.
//  Copyright (c) 2014 Technomagination, LLC. All rights reserved.
//

#import "ExportManager.h"
#import <CHCSVParser/CHCSVParser.h>

@interface ExportManager()

@property (nonatomic, strong) NSArray * objectKeys;
@property (nonatomic, strong) CHCSVWriter * writer;

-(NSError*)invalidDataFormatError;

@end

@implementation ExportManager

-(id)init
{
    self = [super init];
    if(self != nil) {
        self.objectKeys = [NSMutableArray array];
    }
    return self;
}

-(void)beginExportJSONFile:(NSURL*)jsonFileUrl
                 toCSVFile:(NSURL*)csvFileUrl
     updateProgressHandler:(void (^)(CGFloat percentComplete))progress
         completionHandler:(void (^)(NSError * error))completion
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        //Load the contents of the json file
        NSError * error = nil;
        NSData * jsonData = [NSData dataWithContentsOfFile:jsonFileUrl.path options:0 error:&error];
        
        if(error == nil && jsonData != nil) {
            id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
            if(error == nil && [jsonObject isKindOfClass:[NSDictionary class]]) {
                NSDictionary * dictionary = (NSDictionary*)jsonObject;
                
                if([[dictionary objectForKey:@"results"] isKindOfClass:[NSArray class]]) {
                
                    NSArray * resultsArray = (NSArray*)[dictionary objectForKey:@"results"];
                    NSLog(@"Deserialized %lu objects", (unsigned long)resultsArray.count);
                    
                    if(resultsArray.count == 0) {
                        error = [self invalidDataFormatError];
                    } else {
                        NSMutableSet * uniqueKeysSet = [NSMutableSet set];

                        //Loop through all of the objects and get all of the unique keys
                        for(int i = 0; i < resultsArray.count; ++i) {
                            NSDictionary * objectDictionary = [resultsArray objectAtIndex:i];
                            for(NSString * key in objectDictionary.allKeys) {
                                [uniqueKeysSet addObject:key];
                            }
                        }
                        
                        self.objectKeys = [[uniqueKeysSet allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

                        NSLog(@"Loaded %lu unique keys for fields.", (unsigned long)self.objectKeys.count);
                        
                        self.writer = [[CHCSVWriter alloc] initForWritingToCSVFile:csvFileUrl.path];
                        
                        //Loop through the obejcts and create the CSV file
                        for(int i = 0; i < resultsArray.count; ++i) {
                            NSDictionary * objectDictionary = [resultsArray objectAtIndex:i];
                            
                            if(i == 0) {
                                //Loop over the keys and out to CSV field headers
                                for(NSString * key in self.objectKeys) {
                                    [self.writer writeField:key];
                                }
                                [self.writer finishLine];
                            }
                            
                            //Loop over the keys and out to CSV fields
                            for(NSString * key in self.objectKeys) {
                                
                                //Use the static method that translates objects into strings
                                [self.writer writeField:[ExportManager stringValueForKey:key inObjectDictionary:objectDictionary]];
                                
                            }
                            
                            [self.writer finishLine];
                            
                            __block CGFloat percentComplete = (i * 1.0 / resultsArray.count * 1.0) * 100.0;
                            
                            //NSLog(@"Exported %d of %lu records", i, (unsigned long)resultsArray.count);
                            dispatch_async(dispatch_get_main_queue(), ^{
                                progress(percentComplete);
                            });
                        }
                        
                        [self.writer closeStream];
                    }
                } else {
                    error = [self invalidDataFormatError];
                }
            } else {
                error = [self invalidDataFormatError];
            }
        } else {
            error = [self invalidDataFormatError];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            //Call the completion handler and pass the error along.  It's initialized to nil to begin with - the success case
            completion(error);
        });
    });
}

-(NSError*)invalidDataFormatError
{
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"File does not contain any Parse.com formatted JSON data.", nil),
                                NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"No records in results array.", nil),
                                NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Check data format.", nil)
                                };
    return [NSError errorWithDomain:@"com.technomagination.ParseToCSV" code:-10 userInfo:userInfo];
}

+(NSString*)stringValueForKey:(NSString*)key inObjectDictionary:(NSDictionary*)dictionary
{
    id value = [dictionary objectForKey:key];
    
    NSString * outputValueString = @"";
    
    if ([value isKindOfClass:[NSString class]]) {
        outputValueString = (NSString*)value;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber * number = (NSNumber*)value;
        if (number == (void*)kCFBooleanFalse || number == (void*)kCFBooleanTrue) {
            outputValueString = [number boolValue] ? @"true" : @"false";
        } else
            outputValueString = [((NSNumber*)value) stringValue];
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary * valueDictionary = (NSDictionary*)value;
        
        NSString * type = [valueDictionary objectForKey:@"__type"];
        if([type isEqualToString:@"GeoPoint"]) {
            NSNumber * latitude = [valueDictionary objectForKey:@"latitude"];
            NSNumber * longitude = [valueDictionary objectForKey:@"longitude"];
            outputValueString = [NSString stringWithFormat:@"(%@,%@)", latitude.stringValue, longitude.stringValue];
        } else if ([type isEqualToString:@"Date"]) {
            if([[valueDictionary objectForKey:@"iso"] isKindOfClass:[NSString class]])
                outputValueString = [valueDictionary objectForKey:@"iso"];
        } else if ([type isEqualToString:@"File"]) {
            if([[valueDictionary objectForKey:@"url"] isKindOfClass:[NSString class]])
                outputValueString = [valueDictionary objectForKey:@"url"];
        } else if ([type isEqualToString:@"Bytes"]) {
            if([[valueDictionary objectForKey:@"base64"] isKindOfClass:[NSString class]])
                outputValueString = [valueDictionary objectForKey:@"base64"];
        } else if ([type isEqualToString:@"Pointer"]) {
            if([[valueDictionary objectForKey:@"objectId"] isKindOfClass:[NSString class]])
                outputValueString = [valueDictionary objectForKey:@"objectId"];
        } else {
            if(type != nil && type.length > 0)
                outputValueString = [NSString stringWithFormat:@"[[%@]]", type];
            else
                outputValueString = valueDictionary.description;
                //outputValueString = [NSString stringWithFormat:@"%lu key value pairs", (unsigned long)valueDictionary.count];
        }
    } else if ([value isKindOfClass:[NSNull class]]) {
        outputValueString = @"null";
    } else if ([value isKindOfClass:[NSArray class]]) {
        outputValueString = [value description];
    }
    return outputValueString;
}

@end
