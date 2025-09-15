//
//  SortablePicture.h
//  GCDImageSorts
//
//  Contains: Header file for the Sortable Picture abstract base class.
//           Modern sorting visualization using AppKit and Grand Central Dispatch.
//
//  Originally by Karl Groethe, 2000
//  Modernized for macOS 11.0+, 2024
//

#ifndef SORTABLE_PICTURE_H
#define SORTABLE_PICTURE_H

#import <Cocoa/Cocoa.h>
#include <chrono>

/**
 * GCDImageSorts - Modern Sorting Algorithm Visualization
 * 
 * A high-performance image-based sorting algorithm visualization tool that demonstrates
 * various sorting algorithms running concurrently using Grand Central Dispatch.
 * Features real-time visualization with customizable frame rates and statistics.
 */

#define kAppCreator 'GcdS'

// Uncomment to enable runtime speed control via keyboard shortcuts
//#define SPEED_CONTROL

/**
 * SortablePicture - Abstract base class for sorting algorithm visualizations
 * 
 * This class provides the foundation for visualizing sorting algorithms on
 * image data. Each sorting algorithm subclass implements the Sort() method
 * while inheriting common functionality for display, timing, and statistics.
 */
class SortablePicture
{
public:
    enum { Class_ID = 'Spic' };
    
    SortablePicture();
    virtual ~SortablePicture();
    
    virtual NSString* GetSortName() { return @""; }
    virtual NSString* GetBigONotation() { return @"O(?)"; }
    virtual void CreatePictWindow();
    virtual void DisposePictWindow();
    virtual void AllocPictBitmap();
    virtual void DisposePictBitmap();
    virtual void AllocPixelArrays();
    virtual void DisposePixelArrays();
    virtual void Scramble();
    virtual void Sort() {};
    
    // Image loading functionality
    virtual void LoadImageFromFile(NSString* imagePath);
    virtual void CreateGradientPattern();
    
    void SwapBytes(uint8_t* a, uint8_t* b, uint32_t numBytes);
    virtual void SwapPixels(uint32_t indexA, uint32_t indexB);
    virtual bool InOrder(uint32_t indexA, uint32_t indexB);
    virtual void Draw();
    virtual void ForceDraw();  // Draw without timing throttle
    virtual void UpdateStats();
    
    // Timing methods
    virtual void StartSortTimer();
    virtual void EndSortTimer();
    virtual bool IsRunning() const;
    virtual void DrawTimingOverlay();
    virtual void DrawAlgorithmOverlay();
    virtual void clearAllOverlays();
    virtual void clearStatisticsOverlays();
    virtual void clearTemporaryOverlays();
    virtual void showBigTimingDisplay(NSString* timingText);
    virtual void hideBigTimingDisplay();
    virtual NSString* formatDurationMs(double durationMs);
    virtual void createPersistentOverlayFields();
    virtual void updateOverlayInfo();
    virtual void resetSorting();
    
    bool GetShowStats();
    void SetShowStats(bool show);
    bool GetOverlaysEnabled();
    void SetOverlaysEnabled(bool enabled);
    
    void SetWindowFrame(NSRect frame);
    NSWindow* GetWindow();
    
    static void DisposePictureWindow(NSWindow* window);
    static void* DrawThread(void* inPict);
    static void* ScrambleAndSortThread(void* inPict);
    
    timespec GetFrameWaitTime();
    
#ifdef SPEED_CONTROL
    void SetFrameWaitTime(long waitTime);
    timespec GetSwapWaitTime();
    void SetSwapWaitTime(long waitTime);
#endif

protected:
    // Window and UI components
    
    NSWindow* pictWindow;
    NSImageView* imageView;
    NSTextField* statsLabel;
    
    // Persistent overlay fields (created once, hidden/shown as needed)
    NSTextField* algorithmNameField;
    NSTextField* bigOField;
    NSTextField* timingField;
    NSTextField* statsField;
    NSTextField* imageInfoField;
    uint8_t* pixelBuffer;           // Direct pixel buffer (RGBA)
    NSImage* displayImage;          // NSImage for display
    uint8_t* originalBitmapData;    // Store the original unscrambled pattern
    NSRect pictBounds;
    
    uint32_t* pixelIndexArray;
    uint32_t* pixelOffsetArray;
    uint32_t bytesPerPixel;
    uint32_t bytesPerRow;
    uint32_t pictWidth;
    uint32_t pictHeight;
    uint32_t linearPictSize;
    CGFloat displayScale;               // Display scale factor for large images
    uint64_t swaps;
    uint64_t comparisons;
    
    timeval frameTime;
    uint32_t lastSwapVal;
    
    // Timing for performance tracking
    std::chrono::high_resolution_clock::time_point sortStartTime;
    std::chrono::high_resolution_clock::time_point sortEndTime;
    std::chrono::high_resolution_clock::time_point lastDrawTime; // For 30fps drawing
    double sortDurationMs;
    bool sortCompleted;

private:
    bool showStats;
    bool overlaysEnabled; // Controls whether overlays should be shown during sorting
    timespec frameWaitTime;
#ifdef SPEED_CONTROL
    timespec swapWaitTime;
#endif
    
public:
    bool victoryScreenVisible;
};

#endif
