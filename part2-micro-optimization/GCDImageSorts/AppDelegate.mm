//
//  AppDelegate.mm
//  GCDImageSorts
//
//  Modern AppKit-based sorting algorithm visualization
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#import "AppDelegate.h"
#import "SortablePicture.h"
#import "BubbleSortPicture.h"
#import "SelectionSortPicture.h"
#import "InsertionSortPicture.h"
#import "ShellSortPicture.h"
#import "QuickSortPicture.h"
#import "HeapSortPicture.h"
#import "ThreadedQuickSortPicture.h"
#import "OptimizedBubbleSortPicture.h"
#import "OptimizedQuickSortPicture.h"
#import "FixedQuickSortPicture.h"
#import "RadixSortPicture.h"
#include <vector>

@interface AppDelegate ()
@property (nonatomic, strong) NSWindow *mainWindow;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSStackView *gridContainer;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.activeSortPictures = [[NSMutableArray alloc] init];
    self.algorithmVisibility = [[NSMutableArray alloc] init];
    self.sortingInProgress = NO;
    self.sequentialSorting = YES; // Default to sequential sorting
    self.shouldAutoStart = NO; // Default to manual start
    
    // Create windows for all sorting algorithms in a grid layout
    [self createAlgorithmComparisonGrid];
    [self createAlgorithmSelectionMenu];
    
    // Process command line arguments
    [self processLaunchArguments];
    
    // Set up global click monitor for victory screen dismissal
    [self setupVictoryScreenClickHandler];
    
    // Auto-start after 2 seconds if requested
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.shouldAutoStart) {
            [self startAllSorting:nil];
        }
    });
    //     [self startAllSorting:nil];
    // });
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Clean up any running sorts
}

- (void)createAlgorithmComparisonGrid {
    // Create windows for different sorting algorithms arranged in a grid
    
    // Arrange windows in a 3x3 grid for 9 algorithms (perfect square layout)
    int windowWidth = 480;
    int windowHeight = 360;
    int spacing = 15;
    
    // Get screen dimensions to position at top of screen
    NSScreen* mainScreen = [NSScreen mainScreen];
    NSRect screenFrame = [mainScreen visibleFrame];
    
    int startX = 50;
    // Calculate starting Y to fit 3 rows on screen with spacing (macOS coordinates: Y=0 at bottom)
    int totalGridHeight = 3 * windowHeight + 2 * spacing;
    int startY = screenFrame.size.height - windowHeight - 50;  // Start from top
    
    // Create all algorithm instances ordered by actual performance (fastest to slowest)
    std::vector<SortablePicture*> algorithms = {
        new RadixSortPicture(),                // 0 - Ultra Radix Sort (0.007s)
        new FixedQuickSortPicture(),          // 1 - Optimized QuickSort (0.009s)
        new OptimizedBubbleSortPicture(),     // 2 - Optimized Bubble Sort (0.014s)
        new ThreadedQuickSortPicture(1),      // 3 - GCD Concurrent QuickSort (fast)
        new HeapSortPicture(),                // 4 - Heap Sort (0.036s)
        new ShellSortPicture(),               // 5 - Shell Sort (0.069s)
        new ThreadedQuickSortPicture(2),      // 6 - Merge Sort (0.109s)
        new SelectionSortPicture(),           // 7 - Selection Sort (O(n²))
        new InsertionSortPicture(),           // 8 - Insertion Sort (very slow O(n²))
        new BubbleSortPicture(),              // 9 - Bubble Sort (slowest O(n²))
        new BiDirBubbleSortPicture()          // 10 - Bidirectional Bubble Sort (hidden)
    };
    
    // Clear existing arrays
    [self.activeSortPictures removeAllObjects];
    [self.algorithmVisibility removeAllObjects];
    
    for (int i = 0; i < algorithms.size(); i++) {
        SortablePicture* sortPicture = algorithms[i];
        
        // Calculate grid position (3 columns, 3 rows) for 9 visible algorithms
        // Visual layout: top-left (fastest) to bottom-right (slowest)
        int col = i % 3;
        int row = i / 3;
        int x = startX + col * (windowWidth + spacing);
        // Position rows from top down (subtract because macOS Y=0 is at bottom)
        int y = startY - row * (windowHeight + spacing);
        
        // Position the window
        NSRect windowFrame = NSMakeRect(x, y, windowWidth, windowHeight);
        sortPicture->SetWindowFrame(windowFrame);
        
        // Store for later reference
        NSValue *sortPictureValue = [NSValue valueWithPointer:sortPicture];
        [self.activeSortPictures addObject:sortPictureValue];
        
        // Default visibility: show first 9 algorithms for perfect 3x3 grid
        BOOL isVisible = (i < 9); // Show all algorithms except BiDirBubbleSortPicture
        [self.algorithmVisibility addObject:@(isVisible)];
        
        // Hide windows for disabled algorithms
        if (!isVisible) {
            NSWindow* window = sortPicture->GetWindow();
            if (window) {
                [window orderOut:nil];
            }
        }
    }
    
    // Set window titles after all objects are fully constructed
    for (int i = 0; i < self.activeSortPictures.count; i++) {
        NSValue *sortPictureValue = [self.activeSortPictures objectAtIndex:i];
        SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
        if (sortPicture) {
            NSWindow* window = sortPicture->GetWindow();
            NSString* algorithmName = sortPicture->GetSortName();
            if (window && algorithmName && ![algorithmName isEqualToString:@""]) {
                [window setTitle:algorithmName];
                [window setTitleVisibility:NSWindowTitleVisible];
                
                // Now that GetSortName() works, update the info overlay
                sortPicture->updateOverlayInfo();
            }
        }
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;  // Keep app running even if windows are closed
}

#pragma mark - Menu Actions

- (IBAction)startAllSorting:(id)sender {
    
    // Disable image loading during sorting
    self.sortingInProgress = YES;
    [self updateLoadImageMenuState];
    
    // Count only visible algorithms
    NSInteger totalSorts = 0;
    NSMutableArray* visibleSortPictures = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < self.activeSortPictures.count; i++) {
        if ([[self.algorithmVisibility objectAtIndex:i] boolValue]) {
            totalSorts++;
            NSValue *sortPictureValue = [self.activeSortPictures objectAtIndex:i];
            [visibleSortPictures addObject:sortPictureValue];
        }
    }
    
    // If no algorithms are visible, re-enable image loading immediately
    if (totalSorts == 0) {
        self.sortingInProgress = NO;
        [self updateLoadImageMenuState];
        return;
    }
    
    if (self.sequentialSorting) {
        // Sequential sorting - one at a time
        [self startSequentialSorting:visibleSortPictures atIndex:0];
    } else {
        // Parallel sorting - all at once (original behavior)
        [self startParallelSorting:visibleSortPictures];
    }
}

- (void)startSequentialSorting:(NSArray*)sortPictures atIndex:(NSInteger)index {
    if (index >= sortPictures.count) {
        // All done - keep display updates running and re-enable image loading
        // [self stopDisplayUpdates];  // Keep display updates running to show final results
        self.sortingInProgress = NO;
        [self updateLoadImageMenuState];
        NSLog(@"=== ALL SEQUENTIAL SORTING COMPLETED - APP STAYS RUNNING ===");
        return;
    }

    // Start display updates for the first algorithm
    if (index == 0) {
        [self startDisplayUpdates];
    }
    
    NSValue *sortPictureValue = sortPictures[index];
    SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
    
    if (sortPicture) {
        // Hide any victory screen before starting
        sortPicture->hideBigTimingDisplay();
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            sortPicture->StartSortTimer();
            sortPicture->Sort();
            sortPicture->EndSortTimer();
            
            dispatch_async(dispatch_get_main_queue(), ^{
                sortPicture->UpdateStats();
                
                // Start next algorithm
                [self startSequentialSorting:sortPictures atIndex:index + 1];
            });
        });
    } else {
        // Skip to next if current is invalid
        [self startSequentialSorting:sortPictures atIndex:index + 1];
    }
}

- (void)startParallelSorting:(NSArray*)sortPictures {
    __block NSInteger completedSorts = 0;
    NSInteger totalSorts = sortPictures.count;
    
    // Start 60fps display updates for smooth visualization
    [self startDisplayUpdates];
    
    for (NSValue *sortPictureValue in sortPictures) {
        SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
        if (sortPicture) {
            // Hide any victory screen before starting
            sortPicture->hideBigTimingDisplay();
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                sortPicture->StartSortTimer();
                sortPicture->Sort();
                sortPicture->EndSortTimer();
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    sortPicture->UpdateStats();
                    
                    // Check if all sorts are complete
                    completedSorts++;
                    if (completedSorts >= totalSorts) {
                        // Stop display updates and re-enable image loading when all sorting is complete
                        [self stopDisplayUpdates];
                        self.sortingInProgress = NO;
                        [self updateLoadImageMenuState];
                        
                        // Auto-quit disabled - app stays open after sorting completes
                        NSLog(@"=== ALL SORTING COMPLETED ===");
                        // dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        //     NSLog(@"=== EXITING NOW ===");
                        //     [[NSApplication sharedApplication] terminate:nil];
                        // });
                    }
                });
            });
        }
    }
}

- (IBAction)resetAllAlgorithms:(id)sender {
    // Reset all currently open sorting windows
    for (NSValue *sortPictureValue in self.activeSortPictures) {
        SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
        if (sortPicture) {
            sortPicture->resetSorting();
        }
    }
}


- (IBAction)loadImage:(id)sender {
    // Prevent image loading during sorting
    if (self.sortingInProgress) {
        NSAlert* alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Cannot Load Image"];
        [alert setInformativeText:@"Please wait for sorting to complete before loading a new image."];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    // Create and configure an open panel for image selection
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setMessage:@"Choose an image to sort"];
    
    // Set allowed file types to common image formats
    [openPanel setAllowedFileTypes:@[@"jpg", @"jpeg", @"png", @"gif", @"bmp", @"tiff", @"tif", @"heic", @"webp"]];
    
    // Show the panel
    [openPanel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSURL* selectedURL = [openPanel URL];
            NSString* imagePath = [selectedURL path];
            
            
            // Load the selected image into all sorting algorithms
            for (NSValue *sortPictureValue in self.activeSortPictures) {
                SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
                if (sortPicture) {
                    sortPicture->LoadImageFromFile(imagePath);
                    sortPicture->Scramble();  // Re-scramble with new image
                    sortPicture->Draw();      // Redraw the scrambled image
                    sortPicture->UpdateStats(); // Reset stats
                }
            }
            
            // Small delay to ensure all window resizing is complete before repositioning
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self repositionAlgorithmWindows];
            });
        }
    }];
}

- (void)repositionAlgorithmWindows {
    // Reposition windows in a grid layout that accommodates different sizes
    int spacing = 10;  // Reduced spacing for larger windows
    int startX = 20;   // Reduced margin
    int maxWindowsPerRow = 4;  // Four windows per row for 8 visible algorithms in 2x4 grid
    
    // Get screen dimensions to position at top of screen
    NSScreen* mainScreen = [NSScreen mainScreen];
    NSRect screenFrame = [mainScreen visibleFrame];
    int startY = screenFrame.size.height - 50;  // Start from top of screen
    
    int currentX = startX;
    int currentY = startY;
    int rowHeight = 0;
    int windowCount = 0;
    
    for (int i = 0; i < self.activeSortPictures.count; i++) {
        // Skip hidden windows
        if (![[self.algorithmVisibility objectAtIndex:i] boolValue]) {
            continue;
        }
        
        NSValue *sortPictureValue = [self.activeSortPictures objectAtIndex:i];
        SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
        if (sortPicture) {
            // Get the current window frame to determine its size
            NSWindow* window = sortPicture->GetWindow();
            if (window) {
                NSRect windowFrame = [window frame];
                
                // Check if we need to move to the next row
                if (windowCount > 0 && windowCount % maxWindowsPerRow == 0) {
                    currentX = startX;
                    currentY -= (rowHeight + spacing);  // Move down from top
                    rowHeight = 0;
                }
                
                // Position the window (currentY is already in screen coordinates from top)
                windowFrame.origin.x = currentX;
                windowFrame.origin.y = currentY - windowFrame.size.height;
                
                [window setFrame:windowFrame display:YES animate:YES];
                
                // Update position for next window
                currentX += windowFrame.size.width + spacing;
                rowHeight = MAX(rowHeight, (int)windowFrame.size.height);
                windowCount++;
                
            }
        }
    }
}

- (void)updateLoadImageMenuState {
    // Find the "Load Image..." menu item by searching through the main menu
    NSMenu* mainMenu = [NSApp mainMenu];
    
    for (NSMenuItem* topLevelItem in [mainMenu itemArray]) {
        if ([[topLevelItem title] isEqualToString:@"File"]) {
            NSMenu* fileMenu = [topLevelItem submenu];
            for (NSMenuItem* menuItem in [fileMenu itemArray]) {
                if ([[menuItem title] isEqualToString:@"Load Image..."]) {
                    // Disable/enable the menu item based on sorting state
                    [menuItem setEnabled:!self.sortingInProgress];
                    return;
                }
            }
        }
    }
    
}

- (void)createAlgorithmSelectionMenu {
    // Get the main menu and find the Algorithm menu
    NSMenu* mainMenu = [NSApp mainMenu];
    NSMenuItem* algorithmMenuItem = nil;
    
    // Find the Algorithm menu
    for (NSMenuItem* item in [mainMenu itemArray]) {
        if ([[item title] isEqualToString:@"Algorithm"]) {
            algorithmMenuItem = item;
            break;
        }
    }
    
    if (!algorithmMenuItem) {
        // Create Algorithm menu if it doesn't exist
        algorithmMenuItem = [[NSMenuItem alloc] initWithTitle:@"Algorithm" action:nil keyEquivalent:@""];
        NSMenu* algorithmMenu = [[NSMenu alloc] initWithTitle:@"Algorithm"];
        [algorithmMenuItem setSubmenu:algorithmMenu];
        [mainMenu insertItem:algorithmMenuItem atIndex:[mainMenu numberOfItems] - 1];
    }
    
    NSMenu* algorithmMenu = [algorithmMenuItem submenu];
    
    // Add separator if menu has items
    if ([algorithmMenu numberOfItems] > 0) {
        [algorithmMenu addItem:[NSMenuItem separatorItem]];
    }
    
    // Add sequential sorting toggle
    NSMenuItem* sequentialItem = [[NSMenuItem alloc] initWithTitle:@"Sort Sequentially (One at a Time)"
                                                           action:@selector(toggleSequentialSorting:)
                                                    keyEquivalent:@""];
    [sequentialItem setTarget:self];
    [sequentialItem setState:NSControlStateValueOff]; // Default to parallel
    [algorithmMenu addItem:sequentialItem];
    
    // Add statistics toggle
    NSMenuItem* statsItem = [[NSMenuItem alloc] initWithTitle:@"Show Statistics"
                                                      action:@selector(toggleStatisticsDisplay:)
                                               keyEquivalent:@""];
    [statsItem setTarget:self];
    [statsItem setState:NSControlStateValueOn]; // Default to showing stats
    [algorithmMenu addItem:statsItem];
    
    // Add another separator before algorithm list
    [algorithmMenu addItem:[NSMenuItem separatorItem]];
    
    // Add algorithm window toggles (must match the algorithms array indices exactly!)
    NSArray* algorithmNames = @[
        @"Radix Sort",               // 0 - RadixSortPicture (Ultra Radix Sort O(n)!)
        @"Fixed Quick Sort",         // 1 - FixedQuickSortPicture (Fixed Optimized QuickSort)
        @"Optimized Quick Sort",     // 2 - OptimizedQuickSortPicture (Ultra-Optimized QuickSort)
        @"GCD Concurrent Quick Sort", // 3 - ThreadedQuickSortPicture(1) (GCD Concurrent QuickSort)
        @"Quick Sort",               // 4 - QuickSortPicture (Regular QuickSort)
        @"Heap Sort",                // 5 - HeapSortPicture (Heap Sort)
        @"Merge Sort",               // 6 - ThreadedQuickSortPicture(2) (Merge Sort)
        @"Shell Sort",               // 7 - ShellSortPicture (Shell Sort)
        @"Selection Sort",           // 8 - SelectionSortPicture (Selection Sort)
        @"Insertion Sort",           // 9 - InsertionSortPicture (Insertion Sort)
        @"Bubble Sort",              // 10 - BubbleSortPicture (Bubble Sort - slowest)
        @"Optimized Bubble Sort",    // 11 - OptimizedBubbleSortPicture (Optimized Bubble Sort)
        @"Reverse Bubble Sort",      // 12 - RBubbleSortPicture (Reverse Bubble Sort - hidden)
        @"Bidirectional Bubble Sort" // 13 - BiDirBubbleSortPicture (Bidirectional Bubble Sort - hidden)
    ];
    
    for (int i = 0; i < algorithmNames.count; i++) {
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:algorithmNames[i] 
                                                     action:@selector(toggleAlgorithmWindow:) 
                                              keyEquivalent:@""];
        [item setTarget:self];
        [item setTag:i];
        // Set initial state based on default visibility  
        BOOL isVisible = (i == 0 || i == 1); // Match the visibility logic above - both QuickSorts
        [item setState:isVisible ? NSControlStateValueOn : NSControlStateValueOff];
        [algorithmMenu addItem:item];
    }
}

- (IBAction)toggleAlgorithmWindow:(id)sender {
    NSMenuItem* menuItem = (NSMenuItem*)sender;
    NSInteger algorithmIndex = [menuItem tag];
    
    if (algorithmIndex >= 0 && algorithmIndex < self.activeSortPictures.count) {
        // Check if Option key is held down
        NSEvent* currentEvent = [NSApp currentEvent];
        BOOL optionKeyPressed = ([currentEvent modifierFlags] & NSEventModifierFlagOption) != 0;
        
        if (optionKeyPressed) {
            // Option+click: Hide all others, show only this one
            [self showOnlyAlgorithm:algorithmIndex];
        } else {
            // Normal click: Toggle this algorithm
            BOOL isVisible = [[self.algorithmVisibility objectAtIndex:algorithmIndex] boolValue];
            BOOL newVisibility = !isVisible;
            
            [self.algorithmVisibility replaceObjectAtIndex:algorithmIndex withObject:@(newVisibility)];
            
            // Update menu item state
            [menuItem setState:newVisibility ? NSControlStateValueOn : NSControlStateValueOff];
            
            // Show/hide the window
            NSValue *sortPictureValue = [self.activeSortPictures objectAtIndex:algorithmIndex];
            SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
            if (sortPicture) {
                NSWindow* window = sortPicture->GetWindow();
                if (window) {
                    if (newVisibility) {
                        [window orderFront:nil];
                    } else {
                        [window orderOut:nil];
                    }
                }
            }
            
            // Reposition visible windows
            [self repositionAlgorithmWindows];
        }
    }
}

- (void)showOnlyAlgorithm:(NSInteger)targetIndex {
    // Hide all algorithms except the target one
    for (int i = 0; i < self.activeSortPictures.count; i++) {
        BOOL shouldBeVisible = (i == targetIndex);
        [self.algorithmVisibility replaceObjectAtIndex:i withObject:@(shouldBeVisible)];
        
        // Update window visibility
        NSValue *sortPictureValue = [self.activeSortPictures objectAtIndex:i];
        SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
        if (sortPicture) {
            NSWindow* window = sortPicture->GetWindow();
            if (window) {
                if (shouldBeVisible) {
                    [window orderFront:nil];
                } else {
                    [window orderOut:nil];
                }
            }
        }
    }
    
    // Update all menu item states
    NSMenu* algorithmMenu = nil;
    NSMenu* mainMenu = [NSApp mainMenu];
    for (NSMenuItem* item in [mainMenu itemArray]) {
        if ([[item title] isEqualToString:@"Algorithm"]) {
            algorithmMenu = [item submenu];
            break;
        }
    }
    
    if (algorithmMenu) {
        for (NSMenuItem* item in [algorithmMenu itemArray]) {
            if ([item tag] >= 0 && [item tag] < self.activeSortPictures.count) {
                BOOL shouldBeChecked = ([item tag] == targetIndex);
                [item setState:shouldBeChecked ? NSControlStateValueOn : NSControlStateValueOff];
            }
        }
    }
    
    // Reposition visible windows
    [self repositionAlgorithmWindows];
}

- (IBAction)toggleSequentialSorting:(id)sender {
    NSMenuItem* menuItem = (NSMenuItem*)sender;
    self.sequentialSorting = !self.sequentialSorting;
    [menuItem setState:self.sequentialSorting ? NSControlStateValueOn : NSControlStateValueOff];
    
}

- (IBAction)toggleStatisticsDisplay:(id)sender {
    NSMenuItem* menuItem = (NSMenuItem*)sender;
    
    // Toggle the statistics display for all visible sort pictures
    BOOL showStats = [menuItem state] == NSControlStateValueOff; // Toggle to opposite state
    [menuItem setState:showStats ? NSControlStateValueOn : NSControlStateValueOff];
    
    NSLog(@"toggleStatisticsDisplay: toggled to %s", showStats ? "ON" : "OFF");
    
    // Apply to all visible sort pictures (now including running algorithms)
    for (int i = 0; i < self.activeSortPictures.count; i++) {
        if ([[self.algorithmVisibility objectAtIndex:i] boolValue]) {
            NSValue *sortPictureValue = [self.activeSortPictures objectAtIndex:i];
            SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
            if (sortPicture) {
                NSLog(@"toggleStatisticsDisplay: setting overlays to %s for sort picture %d", 
                      showStats ? "TRUE" : "FALSE", i);
                // FORCE overlays to always be enabled for debugging
                sortPicture->SetOverlaysEnabled(true); // Always true regardless of menu
            }
        }
    }
}

- (void)processLaunchArguments {
    NSArray* arguments = [[NSProcessInfo processInfo] arguments];
    NSString* imageFile = nil;
    NSInteger algorithmIndex = -1;
    
    // Parse arguments looking for --algorithm, --image, and --start
    for (NSInteger i = 1; i < arguments.count; i++) {
        NSString* arg = arguments[i];

        if ([arg isEqualToString:@"--start"]) {
            self.shouldAutoStart = YES;
            NSLog(@"Auto-start enabled via --start argument");
        } else if ([arg isEqualToString:@"--algorithm"] && i + 1 < arguments.count) {
            // --algorithm 0 (for GCD QuickSort), --algorithm gcd, etc.
            NSString* algorithmArg = arguments[i + 1];
            if ([algorithmArg isEqualToString:@"gcd"] || [algorithmArg isEqualToString:@"0"]) {
                algorithmIndex = 0; // GCD Concurrent Quick Sort
            } else if ([algorithmArg isEqualToString:@"quick"] || [algorithmArg isEqualToString:@"1"]) {
                algorithmIndex = 1; // Quick Sort
            } else if ([algorithmArg isEqualToString:@"heap"] || [algorithmArg isEqualToString:@"2"]) {
                algorithmIndex = 2; // Heap Sort
            } else {
                algorithmIndex = [algorithmArg integerValue];
            }
            i++; // Skip the next argument since we consumed it
        } else if ([arg isEqualToString:@"--image"] && i + 1 < arguments.count) {
            imageFile = arguments[i + 1];
            i++; // Skip the next argument since we consumed it
        }
    }
    
    // Apply algorithm visibility if specified
    if (algorithmIndex >= 0 && algorithmIndex < self.activeSortPictures.count) {
        [self showOnlyAlgorithm:algorithmIndex];
    }
    
    // Load image if specified
    if (imageFile && [[NSFileManager defaultManager] fileExistsAtPath:imageFile]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self loadImageFromPath:imageFile];
        });
    }
}

- (void)loadImageFromPath:(NSString*)imagePath {
    // Load the specified image into all visible sorting algorithms
    for (int i = 0; i < self.activeSortPictures.count; i++) {
        if ([[self.algorithmVisibility objectAtIndex:i] boolValue]) {
            NSValue *sortPictureValue = [self.activeSortPictures objectAtIndex:i];
            SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
            if (sortPicture) {
                sortPicture->LoadImageFromFile(imagePath);
                sortPicture->Scramble();  // Re-scramble with new image
                sortPicture->Draw();      // Redraw the scrambled image
                sortPicture->UpdateStats(); // Reset stats
            }
        }
    }
    
    // Small delay to ensure all window resizing is complete before repositioning
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self repositionAlgorithmWindows];
    });
}

- (void)setupVictoryScreenClickHandler {
    // Monitor left mouse clicks globally to dismiss victory screens
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^(NSEvent *event) {
        // Check all sort pictures for visible victory screens
        for (NSValue *sortPictureValue in self.activeSortPictures) {
            SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
            if (sortPicture && sortPicture->victoryScreenVisible) {
                // Check if the click is in this sort picture's window
                NSWindow* window = sortPicture->GetWindow();
                if (window && [event window] == window) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        sortPicture->hideBigTimingDisplay();
                    });
                    break; // Only handle one at a time
                }
            }
        }
    }];
    
    // Also add local monitor for clicks within our windows
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent *(NSEvent *event) {
        for (NSValue *sortPictureValue in self.activeSortPictures) {
            SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
            if (sortPicture && sortPicture->victoryScreenVisible) {
                NSWindow* window = sortPicture->GetWindow();
                if (window && [event window] == window) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        sortPicture->hideBigTimingDisplay();
                    });
                    break;
                }
            }
        }
        return event; // Pass the event through
    }];
}

#pragma mark - Display Update System

- (void)startDisplayUpdates {
    if (self.displayTimer) {
        return; // Already running
    }
    
    NSLog(@"Starting 60fps display updates with NSTimer");
    
    // Create NSTimer for 60fps updates (16.67ms interval)
    self.displayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/60.0
                                                         target:self
                                                       selector:@selector(displayTimerCallback:)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)stopDisplayUpdates {
    if (self.displayTimer) {
        NSLog(@"Stopping display updates");
        [self.displayTimer invalidate];
        self.displayTimer = nil;
    }
}

- (void)displayTimerCallback:(NSTimer *)timer {
    static int callCount = 0;
    callCount++;
    
    // Update all active sort picture displays at 60fps
    for (NSValue *sortPictureValue in self.activeSortPictures) {
        SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
        if (sortPicture) {
            // Always update display to show current state
            sortPicture->Draw();
            sortPicture->UpdateStats();  // Update stats overlay
            sortPicture->updateOverlayInfo();
            
            // Debug log every 30 calls (twice per second during sorting)
            if (callCount % 30 == 0) {
                NSLog(@"Timer callback #%d - updating overlays for running=%s, overlaysEnabled=%s", 
                      callCount, sortPicture->IsRunning() ? "YES" : "NO",
                      sortPicture->GetOverlaysEnabled() ? "YES" : "NO");
            }
        }
    }
}

@end