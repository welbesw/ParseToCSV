//
//  AppDelegate.m
//  ParseToCSV
//
//  Created by William Welbes on 6/11/14.
//  Copyright (c) 2014 Technomagination, LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "ExportManager.h"

@interface AppDelegate()

@property (nonatomic, strong) NSURL * inputFilePathUrl;
@property (nonatomic, strong) NSURL * outputFilePathUrl;

@property (nonatomic, weak) IBOutlet NSTextField * inputFilePathTextField;
@property (nonatomic, weak) IBOutlet NSProgressIndicator * progressIndicator;

@property (nonatomic, weak) IBOutlet NSButton * selectButton;
@property (nonatomic, weak) IBOutlet NSButton * convertButton;

-(IBAction)didTapSelectInputButton:(id)sender;
-(IBAction)didTapConvertButton:(id)sender;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

-(void)awakeFromNib
{
    [self.progressIndicator setHidden:YES];
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

-(IBAction)didTapSelectInputButton:(id)sender
{
    NSOpenPanel * openPanel = [NSOpenPanel openPanel];
    [openPanel setTitle:@"Select the Parse.com JSON export file"];
    [openPanel setAllowedFileTypes:@[@"json"]];
    openPanel.canChooseDirectories = NO;
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if(result == NSFileHandlingPanelOKButton) {
            self.inputFilePathUrl = [openPanel URL];
            NSLog(@"Selected input file: %@", self.inputFilePathUrl.path);
            self.inputFilePathTextField.stringValue = self.inputFilePathUrl.path;
            self.inputFilePathTextField.textColor = [NSColor blackColor];
        }
    }];
}

-(IBAction)didTapConvertButton:(id)sender
{
    if(self.inputFilePathUrl != nil) {
        
        //Present a save dialog
        NSSavePanel * savePanel = [NSSavePanel savePanel];
        [savePanel setTitle:@"Specify export file location."];
        
        NSString * fileName = @"parse-export.csv";
        if(self.inputFilePathUrl != nil)
            fileName = [NSString stringWithFormat:@"%@.csv", [self.inputFilePathUrl.lastPathComponent stringByDeletingPathExtension]];
        
        [savePanel setNameFieldStringValue:fileName];
        [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
            if (result == NSFileHandlingPanelOKButton)
            {
                self.outputFilePathUrl = [savePanel URL];
                NSLog(@"Writing export file to: %@", self.outputFilePathUrl.path);
                
                [self.progressIndicator setHidden:NO];
                [self.progressIndicator startAnimation:self];
                [self.selectButton setEnabled:NO];
                [self.convertButton setEnabled:NO];
                
                ExportManager * exportManager = [[ExportManager alloc] init];
                [exportManager beginExportJSONFile:self.inputFilePathUrl toCSVFile:self.outputFilePathUrl updateProgressHandler:^(CGFloat percentComplete) {
                    //NSLog(@"progress updated to: %f", percentComplete);
                    self.progressIndicator.doubleValue = percentComplete;   //0 to 100
                } completionHandler:^(NSError *error) {
                    if(error == nil) {
                        self.progressIndicator.doubleValue = 1.0;
                        [self.progressIndicator setHidden:YES];
                        
                        self.inputFilePathTextField.stringValue = [NSString stringWithFormat:@"Success!  Converted file to CSV: %@", self.outputFilePathUrl.path];
                        self.inputFilePathTextField.textColor = [NSColor colorWithCalibratedRed:0.0 green:100.0/255.0 blue:0.0 alpha:1.0];
                    } else {
                        NSAlert * alert = [NSAlert alertWithMessageText:@"Error" defaultButton:@"Ok" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Error converting to CSV.  %@", [error localizedDescription]];
                        [alert runModal];
                    }
                    self.progressIndicator.doubleValue = 0.0;
                    [self.progressIndicator setHidden:YES];
                    [self.selectButton setEnabled:YES];
                    [self.convertButton setEnabled:YES];
                }];
            }
        }];
        
    } else {
        NSAlert * alert = [NSAlert alertWithMessageText:@"File Path Required" defaultButton:@"Ok" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please provide an input file path."];
        [alert runModal];
    }
}

@end
