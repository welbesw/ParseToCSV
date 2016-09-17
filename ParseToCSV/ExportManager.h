//
//  ExportManager.h
//  ParseToCSV
//
//  Created by William Welbes on 6/11/14.
//  Copyright (c) 2014 Technomagination, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ExportManager : NSObject

+(NSString*)stringValueForKey:(NSString*)key inObjectDictionary:(NSDictionary*)dictionary;

-(void)beginExportJSONFile:(NSURL*)jsonFileUrl
                 toCSVFile:(NSURL*)csvFileUrl
     updateProgressHandler:(void (^)(CGFloat percentComplete))progress
         completionHandler:(void (^)(NSError * error))completion;

@end
