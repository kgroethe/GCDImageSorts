//
//  AppDelegate.h
//  GCDImageSorts
//
//  Modern AppKit-based sorting algorithm visualization
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) NSMutableArray *activeSortPictures;
@property (nonatomic, strong) NSMutableArray *algorithmVisibility;
@property (nonatomic, weak) IBOutlet NSMenuItem *loadImageMenuItem;
@property (nonatomic, assign) BOOL sortingInProgress;
@property (nonatomic, assign) BOOL sequentialSorting;
@property (nonatomic, assign) BOOL shouldAutoStart;

// Display update system - NSTimer for 60fps updates
@property (nonatomic, strong) NSTimer *displayTimer;

- (IBAction)startAllSorting:(id)sender;
- (IBAction)resetAllAlgorithms:(id)sender;
- (IBAction)loadImage:(id)sender;
- (IBAction)toggleAlgorithmWindow:(id)sender;
- (IBAction)toggleSequentialSorting:(id)sender;
- (void)showOnlyAlgorithm:(NSInteger)targetIndex;
- (void)startSequentialSorting:(NSArray*)sortPictures atIndex:(NSInteger)index;
- (void)startParallelSorting:(NSArray*)sortPictures;

- (void)repositionAlgorithmWindows;

// Display update system
- (void)startDisplayUpdates;
- (void)stopDisplayUpdates;
- (void)displayTimerCallback:(NSTimer *)timer;

@end