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
    self.sequentialSorting = NO; // Default to parallel sorting
    
    // Create windows for all sorting algorithms in a grid layout
    [self createAlgorithmComparisonGrid];
    [self createAlgorithmSelectionMenu];
    
    // Process command line arguments
    [self processLaunchArguments];
    
    // Set up global click monitor for victory screen dismissal
    [self setupVictoryScreenClickHandler];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Clean up any running sorts
}

- (void)createAlgorithmComparisonGrid {
    // Create windows for different sorting algorithms arranged in a grid
    
    // Arrange windows in a 2x4 grid for 8 algorithms (better for 640x480 windows)
    int windowWidth = 640;
    int windowHeight = 480;
    int spacing = 20;
    
    // Get screen dimensions to position at top of screen
    NSScreen* mainScreen = [NSScreen mainScreen];
    NSRect screenFrame = [mainScreen visibleFrame];
    
    int startX = 50;
    int startY = screenFrame.size.height - windowHeight - 50;  // Start from top of screen
    
    // Create all algorithm instances ordered by true performance (fastest to slowest)
    std::vector<SortablePicture*> algorithms = {
        new ThreadedQuickSortPicture(1),      // 0 - GCD Concurrent QuickSort (fastest)
        new QuickSortPicture(),               // 1 - QuickSort
        new HeapSortPicture(),                // 2 - Heap Sort  
        new ThreadedQuickSortPicture(2),      // 3 - Merge Sort
        new ShellSortPicture(),               // 4 - Shell Sort
        new SelectionSortPicture(),           // 5 - Selection Sort
        new InsertionSortPicture(),           // 6 - Insertion Sort
        new BubbleSortPicture(),              // 7 - Bubble Sort (slowest)
        new RBubbleSortPicture(),             // 8 - Reverse Bubble Sort (hidden)
        new BiDirBubbleSortPicture()          // 9 - Bidirectional Bubble Sort (hidden)
    };
    
    // Clear existing arrays
    [self.activeSortPictures removeAllObjects];
    [self.algorithmVisibility removeAllObjects];
    
    for (int i = 0; i < algorithms.size(); i++) {
        SortablePicture* sortPicture = algorithms[i];
        
        // Calculate grid position (4 columns, 2 rows) for 8 visible algorithms
        // Visual layout: top-left (fastest) to bottom-right (slowest)
        int col = i % 4;
        int row = i / 4;
        int x = startX + col * (windowWidth + spacing);
        // Position rows from top down (startY is already at top of screen)
        int y = startY - row * (windowHeight + spacing);
        
        // Position the window
        NSRect windowFrame = NSMakeRect(x, y, windowWidth, windowHeight);
        sortPicture->SetWindowFrame(windowFrame);
        
        // Store for later reference
        NSValue *sortPictureValue = [NSValue valueWithPointer:sortPicture];
        [self.activeSortPictures addObject:sortPictureValue];
        
        // Default visibility: disable extra bubble sorts (indices 8 and 9) 
        BOOL isVisible = (i != 8 && i != 9); // Hide "Reverse Bubble Sort" and "Bidirectional Bubble Sort"
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
    return YES;
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
        // All done - re-enable image loading
        self.sortingInProgress = NO;
        [self updateLoadImageMenuState];
        return;
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
                        // Re-enable image loading when all sorting is complete
                        self.sortingInProgress = NO;
                        [self updateLoadImageMenuState];
                    }
                });
            });
        }
    }
}

- (IBAction)resetAllAlgorithms:(id)sender {
    // Hide any victory screens before resetting
    for (NSValue *sortPictureValue in self.activeSortPictures) {
        SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
        if (sortPicture) {
            sortPicture->hideBigTimingDisplay();
        }
    }
    
    // Recreate the grid to reset all algorithms
    [self createAlgorithmComparisonGrid];
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
    
    // Add algorithm window toggles (ordered by true performance, fastest to slowest)
    NSArray* algorithmNames = @[
        @"GCD Concurrent Quick Sort", // 0 - Fastest
        @"Quick Sort",               // 1
        @"Heap Sort",                // 2  
        @"Merge Sort",               // 3
        @"Shell Sort",               // 4
        @"Selection Sort",           // 5
        @"Insertion Sort",           // 6
        @"Bubble Sort",              // 7 - Slowest
        @"Reverse Bubble Sort",      // 8 - Hidden by default
        @"Bidirectional Bubble Sort" // 9 - Hidden by default
    ];
    
    for (int i = 0; i < algorithmNames.count; i++) {
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:algorithmNames[i] 
                                                     action:@selector(toggleAlgorithmWindow:) 
                                              keyEquivalent:@""];
        [item setTarget:self];
        [item setTag:i];
        // Set initial state based on default visibility  
        BOOL isVisible = (i != 8 && i != 9); // Match the visibility logic above
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
    
    // Apply to all visible sort pictures (now including running algorithms)
    for (int i = 0; i < self.activeSortPictures.count; i++) {
        if ([[self.algorithmVisibility objectAtIndex:i] boolValue]) {
            NSValue *sortPictureValue = [self.activeSortPictures objectAtIndex:i];
            SortablePicture* sortPicture = (SortablePicture*)[sortPictureValue pointerValue];
            if (sortPicture) {
                // Use the new overlaysEnabled flag to control statistics during runtime
                sortPicture->SetOverlaysEnabled(showStats);
            }
        }
    }
}

- (void)processLaunchArguments {
    NSArray* arguments = [[NSProcessInfo processInfo] arguments];
    NSString* imageFile = nil;
    NSInteger algorithmIndex = -1;
    
    // Parse arguments looking for --algorithm and --image
    for (NSInteger i = 1; i < arguments.count; i++) {
        NSString* arg = arguments[i];
        
        if ([arg isEqualToString:@"--algorithm"] && i + 1 < arguments.count) {
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

@end