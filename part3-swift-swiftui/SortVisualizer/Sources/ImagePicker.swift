//
//  ImagePicker.swift
//  SortVisualizer
//
//  Lets you sort your own picture rather than the built in test pattern.
//
//  This is the original PThreadSorts idea taken at its word: scramble a photo,
//  sort it back, and watch the algorithm put it together. A test pattern proves
//  the machinery; a photo of something you recognise is what makes the progress
//  legible, because you can see how far from done it still is.
//

import SwiftUI
import PhotosUI
import CoreGraphics
import ImageIO

struct ImageSourceControls: View {
    @Bindable var runner: SortRunner
    @State private var photoItem: PhotosPickerItem?
    @State private var loadError: String?

    var body: some View {
        HStack(spacing: 12) {
            // No photoLibrary: .shared() here. That opts into the in-process
            // picker, which requires NSPhotoLibraryUsageDescription and crashes
            // without it. The default picker runs out of process and needs no
            // permission, because the user hands over one image rather than the
            // app being granted the library.
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
            .disabled(runner.isRunning)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await load(item) }
            }

            if runner.sourceName != "Test pattern" {
                Button("Test pattern") { runner.useTestPattern() }
                    .disabled(runner.isRunning)
            }
        }
        .alert("Could not load image", isPresented: .constant(loadError != nil)) {
            Button("OK") { loadError = nil }
        } message: { Text(loadError ?? "") }
    }

    private func load(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let cg = Self.decode(data) else {
                await MainActor.run { loadError = "That image could not be decoded." }
                return
            }
            await MainActor.run { runner.load(image: cg, named: "Photo") }
        } catch {
            await MainActor.run { loadError = error.localizedDescription }
        }
    }

    /// Decode with the EXIF orientation applied.
    ///
    /// CGImageSourceCreateImageAtIndex hands back the raw pixel grid and
    /// ignores the orientation tag, so a photo shot in portrait comes out on
    /// its side. Going through the thumbnail API with
    /// kCGImageSourceCreateThumbnailWithTransform applies the rotation, and
    /// asking for the image's own longest edge means nothing is downscaled.
    private static func decode(_ data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        var longestEdge = 4096
        if let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
            let w = props[kCGImagePropertyPixelWidth] as? Int ?? 0
            let h = props[kCGImagePropertyPixelHeight] as? Int ?? 0
            if w > 0, h > 0 { longestEdge = max(w, h) }
        }

        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longestEdge,
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
            ?? CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}
